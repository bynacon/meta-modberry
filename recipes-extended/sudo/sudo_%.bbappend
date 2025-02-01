#inherit extrausers
#PASSWORD = "mypassword"
#USER = "myuser"
#
#EXTRA_USERS_PARAMS = "\
#    useradd -p `openssl passwd ${PASSWORD}` ${USER}; \
#    usermod -a -G sudo ${USER}; \
#"
#
IMAGE_INSTALL:append = " sudo"

# Here we give sudo access to sudo members
update_sudoers(){
    sed -i 's/# %sudo/%sudo/' ${IMAGE_ROOTFS}/etc/sudoers
}

ROOTFS_POSTPROCESS_COMMAND += "update_sudoers;"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = "file://0001_BynaconToSudo \
                 "

do_install:append() {
    install -d ${D}/etc/sudoers.d
    install -m 0644 ${WORKDIR}/0001_BynaconToSudo ${D}/etc/sudoers.d/0001_BynaconToSudo
}