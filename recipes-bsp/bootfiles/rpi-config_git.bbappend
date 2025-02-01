DESCRIPTION =   "Commented config.txt file for the Raspberry Pi. \
                It can be used to set various system configuration parameters."
LICENSE = "MIT"

COMPATIBLE_MACHINE = "^rpi$"

do_deploy:append(){
    CONFIG=${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt

    sed -i '/vc4-kms-v3d/ c\#dtoverlay=vc4-kms-v3d' $CONFIG

    # I2C parameter
        if [ -n "${CHANGE_I2C_BAUDRATE}" ]; then
            sed -i '/dtparam=i2c_arm_baudrate/ c\dtparam=i2c_arm_baudrate=${CHANGE_I2C_BAUDRATE}' $CONFIG
        fi

    ### Parameters by Bynacon ###
        if [ "${ENABLE_UART2}" = "1" ] || [ "${ENABLE_UART4}" = "1" ] || [ "${ENABLE_SPI4}" = "1" ] || [ "${ENABLE_SPI6}" = "1" ] || [ "${ENABLE_SPI6_EXTENDER}" = "1" ] || [ "${ENABLE_SD_CARD}" = "1" ] || [ "${ENABLE_I2C0_PINS_44_45}" = "1" ] || [ "${ENABLE_I2C1_PINS_2_3}" = "1" ] ; then
            echo "" >>$CONFIG #Leerzeile
                echo "#################################################################################" >>$CONFIG
                echo "## Additional Device Tree Parameters by Bynacon" >>$CONFIG
                echo "#################################################################################" >>$CONFIG
            echo "" >>$CONFIG #Leerzeile
        fi

        ### UART ###
            if [ "${ENABLE_UART2}" = "1" ]; then
                echo "## uart2" >>$CONFIG
                echo "##    Enable pins for uart2" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=uart2" >>$CONFIG
                echo "" >>$CONFIG

                echo "##    Set to "off" to disable the uart2" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtparam=uart2=on" >>$CONFIG
                echo "" >>$CONFIG
            fi

            if [ "${ENABLE_UART4}" = "1" ]; then
                echo "## uart4" >>$CONFIG
                echo "##    Enable pins for uart4" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=uart4,ctsrts" >>$CONFIG
                echo "" >>$CONFIG

                echo "##    Set to "off" to disable the uart4" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtparam=uart4=on" >>$CONFIG
                echo "" >>$CONFIG
            fi

        ### SPI ###
            if [ "${ENABLE_SPI4}" = "1" ]; then
                echo "## spi4" >>$CONFIG
                echo "##    Enable pins for spi4 with one cs lines" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=spi4-1cs,cs0_pin=4,cs0_spidev=on" >>$CONFIG
                echo "" >>$CONFIG
            fi

            if [ "${ENABLE_SPI6}" = "1" ]; then
                echo "## spi6" >>$CONFIG
                echo "##    Enable pins for spi6 with one cs lines" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=spi6-1cs,cs0_pin=18,cs0_spidev=on" >>$CONFIG
                echo "" >>$CONFIG
            fi

            if [ "${ENABLE_SPI6_EXTENDER}" = "1" ]; then
                echo "## spi6 extender" >>$CONFIG
                echo "##    Expansion for spi6, additional two CS lines" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=spi6-extended,cs1_pin=17,cs1_spidev=on,cs2_pin=16,cs2_spidev=on" >>$CONFIG
                echo "" >>$CONFIG
            fi

        ### SD-CARD ###
            if [ "${ENABLE_SD_CARD}" = "1" ]; then
                echo "## SD-Card-Bynacon" >>$CONFIG
                echo "##    SD-Card expansion" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=sd0,overclock_50=10" >>$CONFIG
                echo "" >>$CONFIG
            fi

        ### I2C ###
            if [ "${ENABLE_I2C0_PINS_44_45}" = "1" ] || [ "${ENABLE_I2C1_PINS_2_3}" = "1" ]; then
                echo "## i2c" >>$CONFIG
                    echo "##    Enable pins for i2c" >>$CONFIG
                    echo "##" >>$CONFIG
            fi

            if [ "${ENABLE_I2C0_PINS_44_45}" = "1" ]; then
                echo "dtoverlay=i2c0,pins_44_45=1" >>$CONFIG
                echo "dtparam=i2c0=on" >>$CONFIG
                echo "i2c0_baudrate=400000" >>$CONFIG

                echo "" >>$CONFIG
            fi

            if [ "${ENABLE_I2C1_PINS_0_1}" = "1" ]; then
                echo "dtparam=i2c1=on" >>$CONFIG
                echo "i2c1_baudrate=400000" >>$CONFIG
                echo "" >>$CONFIG
            fi

    ### Special configs for Modberry Techbase M40804W-MAX ###
        if [ "${ENABLE_modberry-m40804w-max-m}" = "1" ] || [ "${ENABLE_modberry-m40804w-max}" = "1" ]; then
            echo "#################################################################################" >>$CONFIG
            echo "## Special configs for Modberry Techbase M40804W-MAX" >>$CONFIG
            echo "#################################################################################" >>$CONFIG
        #

        ### GPIO's ###
        #COMPLETE TODO - Implement DIO GPIO18-25
            echo "## dido" >>$CONFIG
            echo "##    Enable pins for digital input and output" >>$CONFIG
            echo "##" >>$CONFIG
            echo "##    Digital input" >>$CONFIG
            echo "gpio=18-21=ip" >>$CONFIG
            echo "gpio=18-21=pd" >>$CONFIG
            echo "" >>$CONFIG
            echo "##    Digital output" >>$CONFIG
            echo "gpio=22-25=op" >>$CONFIG
            echo "gpio=22-25=pu" >>$CONFIG
            echo "" >>$CONFIG
        #

        ### RS242/485 ###
        #COMPLETE TODO - RS242/485 at GPIO32/33
            echo "## ttyAMA0 at GPIO32/33" >>$CONFIG
            echo "##    Enables ttyAMA0 at GPIO32 and GPIO33" >>$CONFIG
            echo "##" >>$CONFIG
            echo "dtoverlay=miniuart-bt" >>$CONFIG
            sed -i '/#core_freq=250/ c\core_freq=250' $CONFIG
            echo "" >>$CONFIG
        #

        ### SPI ###
        #COMPLETE TODO - spi0-2cs activating
            echo "## spi0-2cs" >>$CONFIG
            echo "##    Enable pins for spi0 with two cs lines" >>$CONFIG
            echo "##" >>$CONFIG
            echo "dtoverlay=spi0-2cs,cs0_spidev=on,cs1_spidev=on" >>$CONFIG
            echo "" >>$CONFIG
        #

            ### CAN bus ###
            #NOTE - MCP2515 CAN at spi0.0 => INFO: Configure directly at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "## CAN bus at spi0.0" >>$CONFIG
                #echo "##    Enables CAN at spi0" >>$CONFIG
                #echo "##" >>$CONFIG
                #echo "#dtoverlay=mcp2515-can" >>$CONFIG
                #INFO: IRQ (GPIO012) and CS0 (GPIO08) LINE direct at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "#dtparam=" >>$CONFIG
                #echo "" >>$CONFIG
            #

            ### TPM Module ###
            #COMPLETE TODO - SLB9670 TPM at spi0.1
                echo "## TPM at spi0.1" >>$CONFIG
                echo "##    Enables TPM at spi0" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=slb9670-tpm" >>$CONFIG
                #INFO: CS1 (GPIO07) LINE direct at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "#dtparam= IRQ (GPIO05)" >>$CONFIG
                echo "" >>$CONFIG
            #
        #

        ### I2C0 ###
            ### 1-wire ###
            #TODO - DS2482S-100+ 1-wire at I2C config.txt (Modberry)
                echo "## 1-wire at I2C0" >>$CONFIG
                echo "##    Enables 1-wire at I2C0" >>$CONFIG
                echo "##" >>$CONFIG
                echo "#dtoverlay=" >>$CONFIG
                echo "#dtparam=" >>$CONFIG
                echo "" >>$CONFIG
            #

            ### DIO ###
            #NOTE - MCP23008 DIO at I2C => INFO: Configure directly at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "## mcp23008 at I2C0" >>$CONFIG
                #echo "##    Enables mcp23008 for switchable digital inputs and outputs" >>$CONFIG
                #echo "##" >>$CONFIG
                #echo "#dtoverlay=mcp23017,gpiopin=6,addr=0x20,mcp23008,noints,i2c0" >>$CONFIG
                #echo "#dtparam= IRQ (GPIO06)" >>$CONFIG
                #echo "" >>$CONFIG
            #

            ### Function ###
            #NOTE - MSP23008 Function at I2C => INFO: Configure directly at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "## mcp23008 at I2C0" >>$CONFIG
                #echo "##    Enables mcp23008 for function" >>$CONFIG
                #echo "##" >>$CONFIG
                #echo "#dtoverlay=" >>$CONFIG
                #echo "" >>$CONFIG
            #

            ### RS242/485 ###
            #NOTE - SC16IS740 RS242/485 at I2C => INFO: Configure directly at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "## ttySC0 at I2C0" >>$CONFIG
                #echo "##    Enables ttySC0 at I2C0" >>$CONFIG
                #echo "##" >>$CONFIG
                #echo "#dtoverlay=sc16is740-serial,i2c_gpio_sda=44,i2c_gpio_scl=45" >>$CONFIG
                #echo "#dtparam=int_pin=16,addr=0x4d" >>$CONFIG
                #echo "" >>$CONFIG
            #

            ### EEPROM ###
            #TODO - Add function over EEPROM at config.txt (Modberry)
                echo "## EEPROM at I2C0" >>$CONFIG
                echo "##    Enables EEPROM at I2C0" >>$CONFIG
                echo "##" >>$CONFIG
                echo "#dtoverlay=" >>$CONFIG
                echo "#dtparam=" >>$CONFIG
                echo "" >>$CONFIG
            #

            ### AI ###
            #NOTE - MCP3424 AI at I2C => INFO: Configure directly at machine-dtb (modberry-m40804w-max-m/0001-mood-modberry-cm4-dts.patch)
                #echo "## mcp3424 at I2C0" >>$CONFIG
                #echo "##    Enables mcp3424 for AI at I2C0" >>$CONFIG
                #echo "##" >>$CONFIG
                #echo "#dtoverlay=" >>$CONFIG
                #echo "#dtparam=" >>$CONFIG
                #echo "" >>$CONFIG
            #

            ### RTC ###
            #COMPLETE TODO - MCP7941x RTC at I2C0
                echo "## RTC at I2C0" >>$CONFIG
                echo "##    Enables RTC at I2C0" >>$CONFIG
                echo "##" >>$CONFIG
                echo "dtoverlay=mcp7941x-rtc,mcp7941x" >>$CONFIG
                echo "" >>$CONFIG
            #
        #
    fi
}