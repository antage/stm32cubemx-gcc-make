export

DEBUG = false

DEVICE_FAMILY = STM32F4xx
DEVICE_TYPE = STM32F429xx
DEVICE_MODEL = STM32F429ZI
STARTUP_FILE = stm32f429xx

CMSIS = Drivers/CMSIS
CMSIS_DEVSUP = $(CMSIS)/Device/ST/$(DEVICE_FAMILY)
CMSIS_OPT = -D$(DEVICE_TYPE) -DUSE_HAL_DRIVER
OTHER_OPT = "-D__weak=__attribute__((weak))" "-D__packed=__attribute__((__packed__))" 
CPU = -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16
SYSTEM = arm-none-eabi

LDSCRIPT = $(DEVICE_MODEL)_FLASH.ld

SRCDIR := Src
INCDIR := Inc/

LIBDIR := Drivers/
MDLDIR := Middlewares/

LIBINC := -IInc
#LIBINC += -IMiddlewares/Third_Party/LwIP/system
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/ipv4
LIBINC += -IDrivers/$(DEVICE_FAMILY)_HAL_Driver/Inc
#LIBINC += -IMiddlewares/Third_Party/FatFs/src/drivers
#LIBINC += -IMiddlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F
#LIBINC += -IMiddlewares/ST/STM32_USB_Device_Library/Core/Inc
#LIBINC += -IMiddlewares/ST/STM32_USB_Device_Library/Class/CDC/Inc
#LIBINC += -IMiddlewares/ST/STM32_USB_Host_Library/Core/Inc
#LIBINC += -IMiddlewares/ST/STM32_USB_Host_Library/Class/MSC/Inc
#LIBINC += -IMiddlewares/Third_Party/FatFs/src
#LIBINC += -IMiddlewares/Third_Party/FreeRTOS/Source/include
#LIBINC += -IMiddlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS
#LIBINC += -IMiddlewares/Third_Party/LwIP/system/arch
#LIBINC += -IMiddlewares/Third_Party/LwIP/system/OS
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/ipv4/lwip
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/lwip
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/netif
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/posix
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/include/posix/sys
#LIBINC += -IMiddlewares/Third_Party/LwIP/src/netif/ppp
LIBINC += -IDrivers/CMSIS/Include
LIBINC += -IDrivers/CMSIS/Device/ST/$(DEVICE_FAMILY)/Include


LIBS := ./$(LIBDIR)/$(DEVICE_FAMILY)_HAL_Driver/libstm32fw.a
#LIBS += ./$(MDLDIR)/Third_Party/FatFs/fatfs.a
#LIBS += ./$(MDLDIR)/Third_Party/FreeRTOS/freertos.a
#LIBS += ./$(MDLDIR)/Third_Party/LwIP/lwip.a
#LIBS += ./$(MDLDIR)/ST/STM32_USB_Device_Library/libstm32usbdev.a
#LIBS += ./$(MDLDIR)/ST/STM32_USB_Host_Library/libstm32usbhost.a
	   
CC      = $(SYSTEM)-gcc
CCDEP   = $(SYSTEM)-gcc
LD      = $(SYSTEM)-gcc
AR      = $(SYSTEM)-ar
AS      = $(SYSTEM)-gcc
OBJCOPY = $(SYSTEM)-objcopy
OBJDUMP	= $(SYSTEM)-objdump
GDB		= $(SYSTEM)-gdb
SIZE	= $(SYSTEM)-size
OCD	= sudo openocd \
		-f interface/stlink-v2-1.cfg \
		-f target/stm32f4x_stlink.cfg

INCLUDES = $(LIBINC)
CFLAGS  = $(CPU) $(CMSIS_OPT) $(OTHER_OPT) -Wall -Wfatal-errors -fno-common -fno-strict-aliasing -O2 -g $(INCLUDES)
ifeq ($(DEBUG),true)
	CFLAGS += -DDEBUG
endif
ASFLAGS = $(CFLAGS) -x assembler-with-cpp
LDFLAGS = -Wl,--gc-sections,-Map=$*.map,-cref -T $(LDSCRIPT) $(CPU) -lm --specs=nano.specs
ifeq ($(DEBUG),true)
	LDFLAGS += --specs=rdimon.specs
endif
ARFLAGS = cr
OBJCOPYFLAGS = -Obinary
OBJDUMPFLAGS = -S

STARTUP_OBJ = $(CMSIS_DEVSUP)/Source/Templates/gcc/startup_$(STARTUP_FILE).o

BIN = main.bin

OBJS = $(sort \
	$(patsubst %.c,%.o,$(wildcard Src/*.c)) \
	$(patsubst %.s,%.o,$(wildcard Src/*.s)) \
	$(STARTUP_OBJ))

all: $(BIN)
	@echo $(OBJS)

reset:
	$(OCD) -c init -c "reset run" -c shutdown

flash: $(BIN)
	$(OCD) -c init -c "reset halt" \
	               -c "flash write_image erase "$(BIN)" 0x08000000" \
			       -c "reset run" \
	               -c shutdown

$(BIN): main.out
	$(OBJCOPY) $(OBJCOPYFLAGS) main.out $(BIN)
	$(OBJDUMP) $(OBJDUMPFLAGS) main.out > main.list
	$(SIZE) main.out
	@echo Make finished

main.out: $(LIBS) $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

$(LIBS): libs

libs:
	@$(MAKE) -C $(LIBDIR)
	@$(MAKE) -C $(MDLDIR)

libclean:
	@$(MAKE) -C $(LIBDIR) clean
	@$(MAKE) -C $(MDLDIR) clean

clean: libclean
	-rm -f $(OBJS)
	-rm -f main.list main.out main.hex main.map main.bin .depend
	-rm -f .cproject .mxproject .project blink.elf.launch
	-rm -rf .settings/

depend dep: .depend

include .depend

.depend: Src/*.c
	$(CCDEP) $(CFLAGS) -MM $^ | sed -e 's@.*.o:@Src/&@' > .depend 

.c.o:
	@echo cc $<
	@$(CC) $(CFLAGS) -c -o $@ $<

.s.o:
	@echo as $<
	@$(AS) $(ASFLAGS) -c -o $@ $<

