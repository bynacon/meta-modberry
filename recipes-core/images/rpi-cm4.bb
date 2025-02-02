SUMMARY = "A console-only image that fully supports the target device hardware."
COMPATIBLE_MACHINE = '(modberry-m40804w-max|modberry-m40804w-max-ota|modberry-m40804w-max-basic)'

IMAGE_FEATURES += "splash"

inherit core-image
inherit extrausers

###############################################################################
### Testing
###############################################################################

DEPENDS:append = " \
    dtc-native \
"

#IMAGE_CLASSES += "extrausers"

#https://linux.die.net/man/8/useradd
#https://linux.die.net/man/8/groupadd
#https://www.howtogeek.com/50787/add-a-user-to-a-group-or-second-group-on-linux/

EXTRA_USERS_PARAMS = "\
	useradd -p '' user; \ 
    useradd -p '' mender; \
	usermod -p '' root; \ 
    groupadd docker; \
    groupadd bynacon; \
    groupadd netdev; \
    groupmod -g 1020 docker; \
    groupmod -g 1040 bynacon; \
    groupmod -g 1030 netdev; \
    usermod -a -G sudo,docker,bynacon,dip user; \
	usermod -a -G sudo,docker,bynacon mender; \
	usermod -a -G netdev root; \
"