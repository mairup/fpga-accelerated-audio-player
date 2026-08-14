FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV F4PGA_INSTALL_DIR=/opt/f4pga
ENV PATH=/opt/conda/envs/xc7/bin:/usr/local/sbt/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-21-jdk-headless \
    curl \
    wget \
    git \
    tar \
    xz-utils \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/sbt/sbt/releases/download/v1.9.9/sbt-1.9.9.tgz && \
    tar -xzf sbt-1.9.9.tgz -C /usr/local && \
    rm sbt-1.9.9.tgz

RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-py39_23.1.0-1-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

RUN /opt/conda/bin/conda create -n xc7 -c litex-hub yosys=0.27_29_g0f5e7c244=20230406_083352_py37 symbiflow-yosys-plugins prjxray-tools prjxray-db nextpnr-xilinx vtr-optimized lxml simplejson intervaltree python=3.7 -y && \
    /opt/conda/bin/conda clean -afy

RUN /opt/conda/envs/xc7/bin/pip install python-constraint https://github.com/f4pga/prjxray/archive/master.zip https://github.com/chipsalliance/f4pga/archive/main.zip#subdirectory=f4pga

RUN mkdir -p /opt/f4pga/xc7 && \
    wget -qO- "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/20220920-124259/symbiflow-arch-defs-install-xc7-007d1c1.tar.xz" | tar -xJ -C /opt/f4pga/xc7 && \
    wget -qO- "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/20220920-124259/symbiflow-arch-defs-xc7a50t_test-007d1c1.tar.xz" | tar -xJ -C /opt/f4pga/xc7 && \
    ln -s /opt/f4pga/xc7/share/f4pga/arch/xc7a50t_test /opt/f4pga/xc7/share/f4pga/arch/artix7

WORKDIR /workspace

CMD ["/workspace/scripts/build_in_container.sh"]
