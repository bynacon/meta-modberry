do_deploy:append() {
    CONFIG=${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/cmdline.txt

    sed -i 's/console=serial0,115200/console=serial0,115200 console=tty1 fbcon=rotate:1/g' $CONFIG

}