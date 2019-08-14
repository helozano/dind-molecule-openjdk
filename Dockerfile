FROM docker:dind

#=============
# Java
#=============
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u131
ENV JAVA_ALPINE_VERSION 8.131.11-r2

RUN set -x \
	&& apk add --no-cache \
		openjdk8="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]


#==============
# Python
#==============
# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# install ca-certificates so that HTTPS works consistently
# other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.6.9

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		gnupg \
		tar \
		xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
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
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \

RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

RUN cd /usr/bin \
    && ln -s python3 python

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.2.2
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/0c72a3b4ece313faccb446a96c84770ccedc5ec5/get-pip.py
ENV PYTHON_GET_PIP_SHA256 201edc6df416da971e64cc94992d2dd24bc328bada7444f0c4f2031ae31e8dad

RUN set -ex; \
	\
	wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
	echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c -; \
	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
        rm -f get-pip.py

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

ENV MOLECULE_EXTRAS="azure,docker,docs,ec2,gce,hetznercloud,linode,lxc,openstack,vagrant,windows"

ADD . .
RUN \
    pip wheel \
    -w dist \
    ".[${MOLECULE_EXTRAS}]"

# ✄---------------------------------------------------------------------
# This is an actual target container:


ENV PACKAGES="\
    docker \
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

ENV PIP_INSTALL_ARGS="\
    --only-binary :all: \
    --no-index \
    -f /usr/src/molecule/dist \
    "

ENV GEM_PACKAGES="\
    rubocop \
    json \
    etc \
    "

ENV MOLECULE_EXTRAS="azure,docker,docs,ec2,gce,hetznercloud,linode,lxc,openstack,vagrant,windows"


RUN \
    apk add --update --no-cache ${BUILD_DEPS} ${PACKAGES} && \
    pip install ${PIP_INSTALL_ARGS} "molecule[${MOLECULE_EXTRAS}]" && \
    gem install ${GEM_PACKAGES} && \
    apk del --no-cache ${BUILD_DEPS} && \
    rm -rf /root/.cache


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
    && usermod -aG docker jenkins

EXPOSE 22


