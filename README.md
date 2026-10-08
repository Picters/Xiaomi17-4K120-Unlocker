# Xiaomi17 4K120

KernelSU / ReSukiSU module by **Picters**.

Adds 4K120 to the stock Xiaomi 17 camera while preserving the original 30/60 fps modes. The supported hardware is pudding with the sunny OVX9500 sensor table.

## Install

Download `dist/Xiaomi17-4K120FPS-Unlocker-v1.0.zip`, install it in the KernelSU manager, then reboot. To restore stock, disable or remove the module and reboot.

The installer checks KernelSU, the device, sensor-table compatibility and payload integrity. There is no OS version or build-number check. Systemless bind mounts replace the sensor table and extend `VideoSizeCustom`; system partitions are not flashed.

## Build

Run `python3 scripts/build_zip.py`. Edit the module files in this repository and rebuild the ZIP after changes.

## Validation

The added mode was tested through temporary bind mounts in the stock camera: user videos measured about 119.47 fps, and the original 60 fps mode remained available. Short recordings were checked; boot-time installation, every camera feature and long recording sessions have not been fully validated.

The module supports an exact compatible sensor table, including some firmware sharing identical sensor data. Android 17 / HyperOS4 is not yet runtime-verified.

See [module details](docs/MODULE.md) and [validation status](docs/VALIDATION.txt).
