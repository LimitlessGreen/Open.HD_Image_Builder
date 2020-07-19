FROM debian:buster

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        git-core sudo vim parted bison flex cpio wget \
	build-essential gcc-arm-linux-gnueabihf \
        quilt coreutils qemu qemu-user-static debootstrap zerofree zip unzip dosfstools \
        bsdtar libcap2-bin rsync grep udev xz-utils curl xxd file kmod bc\
        binfmt-support ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY . /openhd_img_builder/

VOLUME [ "/openhd_img_builder/work", "/openhd_img_builder/deploy"]

