# AlmaLinux 9 (RHEL-compatible), igual ao ambiente usado antes para Vivado/Xilinx GUI.
FROM almalinux:9

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN dnf install -y epel-release && \
    /usr/bin/crb enable && \
    dnf install -y --allowerasing \
    glibc-locale-source glibc-langpack-en \
    ca-certificates \
    curl wget git unzip which file net-tools \
    gcc gcc-c++ make cmake \
    python3 python3-pip python3-devel python3-tkinter \
    libX11 libXext libXrender libXtst libXi libXrandr \
    libXinerama libXcursor libXfixes libXdamage libXcomposite \
    libxcb xcb-util xcb-util-image xcb-util-keysyms \
    xcb-util-renderutil xcb-util-wm \
    libxkbcommon libxkbcommon-x11 \
    xorg-x11-utils xorg-x11-server-utils xauth xterm \
    mesa-libGL mesa-libGLU mesa-dri-drivers \
    gtk2 atk cairo pango \
    liberation-fonts fontconfig freetype \
    nss nspr \
    alsa-lib \
    glib2 libSM libICE \
    ncurses ncurses-libs \
    openssl-devel libffi-devel zlib-devel \
    dbus-x11 \
    && dnf clean all \
    && localedef -i en_US -f UTF-8 en_US.UTF-8

ENV XILINX_INSTALL_DIR=/opt/Xilinx

ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} vivado && \
    useradd -u ${UID} -g ${GID} -m -s /bin/bash vivado && \
    mkdir -p /opt/Xilinx && chown -R vivado:vivado /opt/Xilinx && \
    mkdir -p /workspace && chown -R vivado:vivado /workspace

USER vivado
WORKDIR /workspace

CMD ["/bin/bash", "-l"]
