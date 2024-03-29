FROM docker:dind

#=============
# Java
#=============
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed

RUN set -x \
        && apk update \
	&& apk add --no-cache \
        musl \
        java-cacerts \
        openjdk8 \
        python \
        python-dev \
        py-pip \
        build-base 

RUN  apk update \
     && apk add --no-cache --virtual .build-deps  \
                bzip2-dev \
                coreutils \
                dpkg-dev dpkg \
                expat-dev \
                findutils \
                gcc \
                gdbm-dev \
                libc-dev \
                libffi-dev \
                libnsl-dev \
                libtirpc-dev \
                linux-headers \
                make \
                ncurses-dev \
                openssl-dev \
                pax-utils \
                readline-dev \
                sqlite-dev \
                tcl-dev \
                tk \
                tk-dev \
                xz-dev \
                zlib-dev 

RUN python

#================
#Molecule
#================

WORKDIR /usr/src/molecule

ENV PACKAGES="\
    gcc \
    git \
    libffi-dev \
    make \
    musl-dev \
    openssl-dev \
    "
RUN apk add --update --no-cache ${PACKAGES}


# ✄---------------------------------------------------------------------
# This is an actual target container:


ENV PACKAGES="\
    git \
    openssh-client \
    ruby \
    "

ENV BUILD_DEPS="\
    gcc \
    libc-dev \
    make \
    ruby-dev \
    ruby-rdoc \
    "


ENV GEM_PACKAGES="\
    rubocop \
    json \
    etc \
    "


RUN \
    apk add --update --no-cache ${BUILD_DEPS} ${PACKAGES} && \
    gem install ${GEM_PACKAGES} && \
    rm -rf /root/.cache

RUN pip install --user molecule

#================
# Jenkins
#================

# Add user jenkins to the image
RUN adduser --disabled-password jenkins
# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd \
    && mkdir /home/jenkins/.m2 \
    && chown -R jenkins:jenkins /home/jenkins/.m2/ \
    && echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "alias docker='sudo docker '" >> /home/jenkins/.bashrc \
    && mkdir -p /var/run/sshd \
    && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa 

RUN addgroup jenkins dockremap

EXPOSE 22
CMD []

