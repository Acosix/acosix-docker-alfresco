FROM ${docker.from.id}:${docker.from.version}

# Add local transformation tooling
RUN install_clean \
    build-essential \
    autoconf \
    automake \
    autopoint \
    chrpath \
    debhelper \
    dh-autoreconf \
    dh-strip-nondeterminism \
    libfile-stripnondeterminism-perl \
    m4 \
    po-debconf \
    libclang1-3.6 \
    libsigsegv2 \
    doxygen \
#    cm-super-minimal \
#    doxygen-latex \
    libbz2-1.0 \
    libbz2-dev \
#    libcairo-script-interpreter2 \
#    libcairo2-dev \
#    graphviz \
#    libcdt5 \
#    libcgraph6 \
#    libgvc6 \
#    libgvpr2 \
#    libpathplan4 \
    libdjvulibre21 \
    libdjvulibre-dev \
    libexif12 \    
    libexif-dev \
    libfftw3-3 \
    libfftw3-dev \
    libfontconfig1 \
    libfontconfig1-dev \
    libfreetype6 \
    libfreetype6-dev \
    libgdk-pixbuf2.0-0 \
    libgdk-pixbuf2.0-dev \
    libglib2.0-0 \
    libglib2.0-dev \
    libharfbuzz0b \
    libharfbuzz-dev \
    libharfbuzz-gobject0 \
#    libice-dev \
    libjasper1 \
    libjasper-dev \
    libjbig0 \
    libjbig-dev \
    libjpeg8 \
    libjpeg-dev \
#    libjpeg-turbo8-dev \
    libjpeg8-dev \
#    libjs-jquery \
    liblcms2-2 \
    liblcms2-dev \
#    libllvm3.6v5 \
    liblqr-1-0 \
    liblqr-1-0-dev \
    liblzma5 \
    liblzma-dev \
    libobjc4 \
    libobjc-5-dev \
#    libilmbase-dev \
#    libopenexr-dev \
#    libpango1.0-dev \
#    libpcre3-dev \
#    libpcre32-3 \
#    libpcrecpp0v5 \
#    libperl-dev \
#    libpixman-1-dev \
    libpng12-0 \
    libpng12-dev \
    libpotrace0 \
#    libptexenc1 \
    libpthread-stubs0-dev \
#    gir1.2-rsvg-2.0 \
#    librsvg2-bin \
#    librsvg2-dev \
#    libsm-dev \
#    libsynctex1 \
#    libtexlua52 \
#    libtexluajit2 \
    libtiffxx5 \
    libtiff5-dev \
    libwmf-bin \
    libwmf-dev \
#    libx11-dev \
#    libxau-dev \
#    libxcb-render0-dev \
#    libxcb-shm0-dev \
#    libxcb1-dev \
#    libxdmcp-dev \
#    libxext-dev \
#    libxft-dev \
#    libxml2-dev \
#    libxml2-utils \
#    libxrender-dev \
#    libxt-dev \
    libzzip-0-13 \
    libzzip-dev \
#    pkg-kde-tools \
#    preview-latex-style \
#    tex-common \
#    texlive-base \
#    texlive-binaries \
#    texlive-extra-utils \
#    texlive-font-utils \
#    texlive-fonts-recommended \
#    texlive-latex-base \
#    texlive-latex-extra \
#    texlive-latex-recommended \
#    texlive-pictures \
#    x11proto-core-dev \
#    x11proto-input-dev \
#    x11proto-kb-dev \
#    x11proto-render-dev \
#    x11proto-xext-dev \
#    xorg-sgml-doctools \
#    xsltproc \
#    xtrans-dev \
    zlib1g \
    zlib1g-dev \
#    xorg-dev \
    libopenjp2-7 \
    libopenjp2-7-dev \
  && wget -O /tmp/ImageMagick.tar.gz https://www.imagemagick.org/download/ImageMagick-${imagemagick.version}.tar.gz \
  && cd /tmp \
  && tar xzf /tmp/ImageMagick.tar.gz \
  && cd /tmp/ImageMagick-${imagemagick.version} \
  && ./configure --prefix=/var/lib/ImageMagick-${imagemagick.version} --with-x=no \
  && make \
  && make install \
  && cd / \
  && rm -rf /tmp/ImageMagick-${imagemagick.version} /tmp/ImageMagick.tar.gz \
  && apt-get autoremove -y \
    build-essential \
    autoconf \
    automake \
    autopoint \
    chrpath \
    debhelper \
    dh-autoreconf \
    dh-strip-nondeterminism \
    libfile-stripnondeterminism-perl \
    m4 \
    po-debconf \
    doxygen \
    libbz2-dev \
    libdjvulibre-dev \
    libexif-dev \
    libfftw3-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libgdk-pixbuf2.0-dev \
    libglib2.0-dev \
    libharfbuzz-dev \
    libjasper-dev \
    libjbig-dev \
    libjpeg-dev \
    libjpeg8-dev \
    liblcms2-dev \
    liblqr-1-0-dev \
    liblzma-dev \
    libobjc-5-dev \
    libpng12-dev \
    libtiff5-dev \
    libwmf-dev \
    zlib1g-dev \
    libzzip-dev \
    libopenjp2-7-dev

RUN wget -O /tmp/wkhtmltox.deb https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb \
   && install_clean \
     fontconfig \
     xfonts-75dpi \
     xfonts-base \
     libjpeg8 \
     libx11-6 \
     libxcb1 \
     libxext6 \
     libxrender1 \
   && apt install -y /tmp/wkhtmltox.deb \
   && rm /tmp/wkhtmltox.deb

# add Alfresco PDF Renderer
COPY *.tgz /tmp/
RUN tar xzf /tmp/alfresco-pdf-renderer-*-linux.tgz \
   && mv alfresco-pdf-renderer /usr/bin/ \
   && rm /tmp/alfresco-pdf-renderer-*-linux.tgz \
   && chmod 755 /usr/bin/alfresco-pdf-renderer

# add prepared files that would be too awkward to handle via RUN / sed
COPY *.jar alfresco.xml alfresco-logrotate.d initAlfresco.sh prepareWarFiles.js alfresco-ng.conf repository-config /tmp/

# apply our Alfresco Repository default configurations
RUN mkdir -p /srv/alfresco/config /srv/alfresco/modules /etc/tomcat8/Catalina/localhost \
   && mv /tmp/*.jar /srv/alfresco/modules/ \
   && mv /tmp/alfresco-global.properties /srv/alfresco/config/ \
   && mv /tmp/alfresco /srv/alfresco/config/ \
   && find /srv/alfresco/config -type d -exec chmod +x '{}' \; \
   && mv /tmp/alfresco.xml /etc/tomcat8/Catalina/localhost/ \
   && mv /tmp/alfresco-logrotate.d /etc/logrotate.d/alfresco \
   && touch /var/lib/tomcat8/logs/.alfresco-logrotate-dummy \
   && mv /tmp/prepareWarFiles.js /var/lib/tomcat8/ \
   && chown -R tomcat8:tomcat8 /srv/alfresco \
   && mv /tmp/alfresco-ng.conf /etc/syslog-ng/conf.d/alfresco-ng.conf \
   && mv /tmp/initAlfresco.sh /etc/my_init.d/50_initAlfresco.sh \
   && chmod +x /etc/my_init.d/50_initAlfresco.sh

# Public HTTP ports for reverse-proxy: 8080 / 8081 (assumed secured via SSL)
# Private HTTP ports for SOLR: 8082 / 8083 (active SSL)
# JMX / RMI port: 5001 (aligned with SOLR + Share images so that each havea a distinct port - it's hard to forward JMX / RMI otherwise due JVM having to know the public port you're exposing via Docker)
# Various protocol ports: 10025 (inboundSMTP) / 10445,10137-10139 (CIFS/SMB) / 10021 FTP (active) / 11000-11099 FTP (passive)
EXPOSE 8080 8081 8082 8083 5001 10445 10137-10139 10025 10021 11000-11099

# we also support /srv/alfresco/defaultArtifacts but don't want to force a volume to be auto-created if not bound
VOLUME ["/srv/alfresco/data", "/srv/alfresco/keystore"]

ENV MAVEN_REQUIRED_ARTIFACTS= \
   ALFRESCO_PLATFORM_VERSION=6.0.7-ga \
   ALFRESCO_API_EXPLORER_VERSION=6.0.7-ga \
   ALFRESCO_MMT_VERSION=6.0 \
   ALFRESCO_ROOT_VERSION=6.0 \
   ALFRESCO_AOS_VERSION=1.1.6 \
   ALFRESCO_VTI_BIN_VERSION=1.1.5 \
   ALFRESCO_SHARE_SERVICES_VERSION=6.0.c \
   ALFRESCO_PLATFORM_WAR_ARTIFACT= \
   ALFRESCO_PLATFORM_ROOT_WAR_ARTIFACT= \
   MAVEN_ACTIVE_REPOSITORIES=alfresco,alfresco_ee,central,ossrh \
   MAVEN_REPOSITORIES_central_URL=https://repo1.maven.org/maven2 \
   MAVEN_REPOSITORIES_alfresco_URL=https://artifacts.alfresco.com/nexus/content/groups/public \
   MAVEN_REPOSITORIES_alfresco_ee_URL=https://artifacts.alfresco.com/nexus/content/groups/private \
   MAVEN_REPOSITORIES_ossrh_URL=https://oss.sonatype.org/content/repositories/snapshots \
   JMX_RMI_PORT=5001

LABEL vendor="${docker.labels.vendor}" \
   ${docker.labels.namespace}.version="${project.version.majorVersion}.${project.version.minorVersion}.${project.version.incrementalVersion}" \
   ${docker.labels.namespace}.is-beta="" \
   ${docker.labels.namespace}.is-production="" \
   ${docker.labels.namespace}.release-date="${docker.labels.release-date}" \
   ${docker.labels.namespace}.maintainer="${docker.labels.maintainer}"