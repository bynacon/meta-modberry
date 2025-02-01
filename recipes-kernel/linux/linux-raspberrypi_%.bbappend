FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "   \
    file://sd0-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://spi6-extended-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://mcp2515-can-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://mcp7941x-rtc-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://mcp23008-function-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://sc16is740-serial-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
    file://slb9670-tpm-overlay.dts;subdir=git/arch/arm64/boot/dts/overlays \
"

SRC_URI:append:modberry-m40804w-max-m = "   \
    file://modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch \
    file://modberry-m40804w-max-m/9670.cfg \
"