# Board Support (device tree and board drivers)

| Field | Value |
| :-- | :-- |
| **Module ID** | `BASE-BSP` |
| **Stack** | `basic` |
| **Spec status** | `draft` |
| **Depends on** | `BASE-INIT`, `BASE-HWT` |
| **Hardware reference** | [M40804W_MAX.md](../../hardware/M40804W_MAX.md) – sections 1–5, 7 |
| **Risk** | `medium` |

---

## 1. Purpose

This module makes all devices of the Modberry M40804W MAX board available in Linux: it defines the board device tree and the kernel drivers for the I2C devices (RTC, EEPROM, ADC, 1-Wire bridge, GPIO expanders) and the native digital inputs and outputs. Applications access the I/O through named GPIO lines and standard kernel interfaces, not through sysfs numbers.

---

## 2. Scope

### In scope

- Board device tree patch and its application for all machines of this layer.
- Drivers and device nodes of RTC, EEPROM, ADC, 1-Wire bridge, DIO expander and function block.
- Native digital inputs and outputs, LEDs and buzzer.

### Out of scope

- CAN, I2C tools, serial interfaces and their udev rules → `BASE-HWT`
- TPM driver → `BASE-TPM`
- Ethernet ports and network names → `BASE-NETD`
- USB devices → `BASE-USB`
- Use of the RTC for time keeping → `BASE-TIME`

---

## 3. Components

| Package | Source layer | Replaces / removes |
| :-- | :-- | :-- |
| Board device tree patch `0001-mood-modberry-cm4-dts.patch` | `meta-modberry` (`linux-raspberrypi_%.bbappend`) | — |
| Kernel: `rtc-ds1307` (MCP7941x), `at24`, `mcp3422`, `ds2482` + `w1`, `pinctrl-mcp23s08`, `leds-gpio` | `linux-raspberrypi` | — |
| `libgpiod-tools` (`gpioinfo`, `gpioget`, `gpioset`) | `meta-openembedded` (meta-oe) | sysfs GPIO (`/sys/class/gpio`) |

---

## 4. Requirements

### 4.1 Device Tree

- `BASE-BSP-01` **MUST** The board device tree patch is applied for every machine of this layer (machine override `modberry-m40804w-max`).
- `BASE-BSP-02` **MUST** Every device of the hardware specification is described in the device tree. No device is instantiated at runtime through sysfs (`new_device`).
- `BASE-BSP-03` **MUST** I2C0 runs on GPIO44/45 (ALT1) and I2C1 on GPIO0/1, with the bus speed of the machine configuration (400 kHz).

### 4.2 Board Devices

- `BASE-BSP-10` **MUST** The RTC MCP79412 (I2C0 0x6f) is bound by its kernel driver and available as `/dev/rtc0`.
- `BASE-BSP-11` **MUST** The EEPROM AT24CS01 (I2C0 0x50) is bound by the `at24` driver and available as NVMEM device.
- `BASE-BSP-12` **MUST** The ADC MCP3424 (I2C0 0x6c) is bound by the `mcp3422` IIO driver; the four 0–10 VDC inputs are readable through IIO.
- `BASE-BSP-13` **MUST** The 1-Wire bridge DS2482S-100+ (I2C0 0x18) is bound by the `ds2482` driver; the 1-Wire bus is available.
- `BASE-BSP-14` **MUST** The DIO expander MCP23008 (I2C0 0x20) is a GPIO chip with interrupt support on GPIO06.
- `BASE-BSP-15` **MUST** LED1 (MCP23008 0x21 GP1, red), LED2 (CM4 GPIO27, green/blue) and the buzzer (MCP23008 0x21 GP5) are available through the LED subsystem (`/sys/class/leds/`).
- `BASE-BSP-16` **MUST** The remaining pins of the function block MCP23008 0x21 (GP0, GP2–GP4, GP6, GP7: PCI/power/reset) are not accessible to user space: they are claimed by the kernel (`gpio-hog` or driver) or have no line name and are excluded by the udev rule of `BASE-BSP-22`.

### 4.3 Digital I/O

- `BASE-BSP-20` **MUST** Native DI1–DI4 (GPIO18–21), DO1–DO4 (GPIO22–25) and DIO1–DIO4 (MCP23008 0x20) are accessed through the GPIO character device (libgpiod), not through sysfs.
- `BASE-BSP-21` **MUST** All I/O lines have names in the device tree (`gpio-line-names`: `DI1` … `DI4`, `DO1` … `DO4`, `DIO1` … `DIO4`), so that applications use names instead of numbers.
- `BASE-BSP-22` **MUST** The GPIO character devices are accessible only to root and the group `fieldbus` (`BASE-HWT-24`).
- `BASE-BSP-23` **MUST** All digital outputs are off (low) after boot until an application sets them.
- `BASE-BSP-24` **SHOULD** The legacy sysfs GPIO interface is disabled in the production kernel (`CONFIG_GPIO_SYSFS` not set).

---

## 5. Configuration

| Target path | Key settings | Req. |
| :-- | :-- | :-- |
| `recipes-kernel/linux/linux-raspberrypi_%.bbappend` | `SRC_URI:append:modberry-m40804w-max` with the board patch | `BASE-BSP-01` |
| Board device tree | nodes for `mcp7941x@6f`, `at24@50`, `mcp3424@6c`, `ds2482@18`, `mcp23008@20` (interrupt GPIO06), `mcp23008@21` | `BASE-BSP-02`, `BASE-BSP-10` … `BASE-BSP-14` |
| Board device tree | `gpio-line-names` for the SoC GPIO controller and `mcp23008@20` | `BASE-BSP-21` |
| Board device tree | `leds-gpio` node: `LED1` (mcp23008@21 GP1), `LED2` (GPIO27), `buzzer` (mcp23008@21 GP5) | `BASE-BSP-15` |
| Board device tree | GPIO22–25 with `output-low` default (pinctrl / `gpio-hog` released to user space) | `BASE-BSP-23` |
| `/etc/udev/rules.d/60-modberry-gpio.rules` | `SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="fieldbus", MODE="0660"` | `BASE-BSP-22` |
| Kernel config fragment | `CONFIG_RTC_DRV_DS1307`, `CONFIG_EEPROM_AT24`, `CONFIG_MCP3422`, `CONFIG_W1_MASTER_DS2482`, `CONFIG_PINCTRL_MCP23S08`, `CONFIG_LEDS_GPIO`; production: `# CONFIG_GPIO_SYSFS is not set` | `BASE-BSP-10` … `BASE-BSP-15`, `BASE-BSP-24` |
| `config.txt` | `dtparam=i2c_arm_baudrate=400000`, I2C0 on pins 44/45 | `BASE-BSP-03` |

---

## 6. Interfaces to Other Modules

### Provides

- `/dev/rtc0` – used by `BASE-TIME`.
- EEPROM (NVMEM) – used by `BASE-PROV` (serial number, `BASE-PROV-33`).
- Named GPIO lines (DI, DO, DIO), ADC (IIO), 1-Wire bus, LEDs – used by the application layer.
- User button line GPIO13 – used by `BASE-HWT` (service mode).

### Consumes

- Group `fieldbus` and udev rule conventions – owned by `BASE-HWT`.
- Machine override and kernel recipe – owned by this layer's machine configuration.

---

## 7. Verification

| Req. | Level | Check | Expected |
| :-- | :-- | :-- | :-- |
| `BASE-BSP-01` | `build` | `bitbake -e virtual/kernel \| grep ^SRC_URI=` | contains `0001-mood-modberry-cm4-dts.patch` |
| `BASE-BSP-02` | `device` | `i2cdetect -y 0` | 0x18, 0x20, 0x21, 0x4d, 0x50, 0x6c, 0x6f bound (`UU`) |
| `BASE-BSP-03` | `device` | `ls /dev/i2c-0 /dev/i2c-1`; `cat /sys/class/i2c-adapter/i2c-0/of_node/clock-frequency` | both present; 400 kHz |
| `BASE-BSP-10` | `device` | `hwclock -r -f /dev/rtc0` | valid time |
| `BASE-BSP-11` | `device` | `ls /sys/bus/nvmem/devices/` | AT24 device present |
| `BASE-BSP-12` | `device` | `cat /sys/bus/iio/devices/iio:device*/name`; read `in_voltage0_raw` | `mcp3424`; value changes with the input |
| `BASE-BSP-13` | `device` | `ls /sys/bus/w1/devices/` | `w1_bus_master1` present |
| `BASE-BSP-14` | `device` | `gpioinfo` | a gpiochip for the MCP23008 at 0x20 |
| `BASE-BSP-15` | `device` | `ls /sys/class/leds/` | `LED1`, `LED2`, `buzzer` |
| `BASE-BSP-16` | `device` | `gpioinfo` for the 0x21 chip; `gpioset` on GP0 as member of `fieldbus` | GP1/GP5 used by `leds-gpio`; GP0, GP2–GP4, GP6, GP7 `used` by the kernel; `gpioset` refused |
| `BASE-BSP-20`, `-21` | `device` | `gpioget $(gpiofind DI1)`; `gpioset $(gpiofind DO1)=1` | works with names |
| `BASE-BSP-22` | `device` | `stat -c '%G %a' /dev/gpiochip*` | `fieldbus 660` |
| `BASE-BSP-23` | `device` | Cold boot, measure DO1–DO4 | all off |
| `BASE-BSP-24` | `rootfs` | `ls <rootfs>/sys/class/gpio` on the device / kernel `.config` | not present / not set |

---

## 8. Constraints & Risks

- `BASE-BSP-01`: the board patch was applied only for the override `modberry-m40804w-max-m` until the override fix (commit `fix(bsp): …`). The former hardware status table marked "Base Pinmuxing", "I2C0 Bus Mapping" and "RTC" as implemented; these states are not verified for the current machines and are tracked as tasks again.
- `BASE-BSP-12`: the `mcp3422` driver reports raw values of the ADC input; the scaling to 0–10 VDC (input divider) is done by the application.
- `BASE-BSP-16`: which of the remaining 0x21 pins is PCI, power or reset is not documented. Claiming all of them for the kernel is safe; a later function that needs one of them (e.g. a controlled reset) needs a new requirement.
- `BASE-BSP-20`: the sysfs numbers in the hardware specification (e.g. 496–503 for the MCP23008) depend on the kernel GPIO base and change between kernels. Named lines (`BASE-BSP-21`) avoid this.
- `BASE-BSP-24`: disabling sysfs GPIO breaks the examples of the hardware specification (section 7) and the diagnostics with `echo … > /sys/class/gpio/export`; diagnostics use `libgpiod-tools` instead.

---

## 9. Open Points

| # | Question | Affects | Decision |
| :-- | :-- | :-- | :-- |
| 1 | Which MCP23008 (0x21) pins are LED1, LED2 (if not GPIO27), buzzer and the PCI/power/reset lines exactly? | `BASE-BSP-15`, `BASE-BSP-16` | **Decided:** LED1 = 0x21 GP1, LED2 = GPIO27, buzzer = 0x21 GP5; all other 0x21 pins (PCI/power/reset) are not accessible to user space. User button = GPIO13. |
| 2 | Origin of the implementation status. | all | **Decided:** the former status table of the hardware specification (section 8) is replaced by tasks of this module; status in `STATUS.md`. |
