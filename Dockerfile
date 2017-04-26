FROM docker:1.9.1-dind
MAINTAINER Zane Cahill <zcahill@zomplabs.com>

ENV JENKINS_HOME /home/jenkins
ENV JENKINS_REMOTNG_VERSION 2.53.1
ENV METEOR_RELEASE ${METEOR_RELEASE:-1.4.3.1}

ENV DOCKER_HOST tcp://0.0.0.0:2375

# Install requirements
RUN apk --update add \
    curl \
    git \
    openjdk8-jre \
    sudo

# Add jenkins user
RUN adduser -D -h $JENKINS_HOME -s /bin/sh jenkins jenkins \
    && chmod a+rwx $JENKINS_HOME

# Allow jenkins user to run docker as root
RUN echo "jenkins ALL=(ALL) NOPASSWD: /usr/local/bin/docker" > /etc/sudoers.d/00jenkins \
    && chmod 440 /etc/sudoers.d/00jenkins

# Install Jenkins Remoting agent
RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar http://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/$JENKINS_REMOTNG_VERSION/remoting-$JENKINS_REMOTNG_VERSION.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/slave.jar

# Gosu installation
RUN GOSU_ARCHITECTURE="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${GOSU_ARCHITECTURE}" && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${GOSU_ARCHITECTURE}.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -R "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu

# Change user to jenkins and install meteor
RUN cd /home/jenkins/ && \
    chown jenkins:jenkins --recursive /home/jenkins && \
    curl https://install.meteor.com -o ./install_meteor.sh && \
    sed -i "s|RELEASE=.*|RELEASE=${METEOR_RELEASE}\"\"|g" ./install_meteor.sh && \
    echo "Starting meteor ${METEOR_RELEASE} installation...   \n" && \
    chown jenkins:jenkins ./install_meteor.sh && \
    gosu jenkins:jenkins sh ./install_meteor.sh && \
    cp "/home/jenkins/.meteor/packages/meteor-tool/1.4.3_1/mt-os.linux.x86_64/scripts/admin/launch-meteor" /usr/bin/meteor

COPY jenkins-slave /usr/local/bin/jenkins-slave

VOLUME $JENKINS_HOME
WORKDIR $JENKINS_HOME

USER jenkins
ENTRYPOINT ["jenkins-slave"]
