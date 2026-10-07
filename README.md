# Nokia 6.1 (PL2) — LineageOS 23.2 (Android 16) Dry-Runner & CI

Minimal, zero-queue GitHub Actions continuous integration and dry-run environment for compiling **LineageOS 23.2 (Android 16)** on **Nokia 6.1 (`PL2` / SDM660)**.

---

## 🚀 Execution Targets

Trigger the workflow under **Actions** → **`Nokia 6.1 (PL2) — LineageOS 23.2 Dry-Runner`**:

| Target | Description | Est. Time | Artifacts |
| :--- | :--- | :--- | :--- |
| **`nothing`** *(Default)* | **Instant Dry-Run & Graph Linting:** Parses Blueprints (`Android.bp`), Kati makefiles (`Android.mk`), and SEPolicy rules to detect syntax, missing dependencies, or macro errors without waiting in public queues. | ~5–10 min | `build-logs-nothing.zip` (`build_a16_PL2.log`) |
| **`bootimage`** | **Kernel & Boot Partition Bringup:** Compiles 4.4 Kernel with backported 5.10 eBPF, generates DTBO overlays, and packages `boot.img`. | ~25–40 min | `PL2-boot-image` (`boot.img`) |
| **`bacon`** | **Full ROM Compilation:** Builds complete LineageOS 23.2 flashable distribution package. | Standard | `PL2-LineageOS-23.2-Package` (`*.zip`) |

---

## 📁 Repository Manifest Mapping

All local source trees are mapped in [`manifests/PL2.xml`](manifests/PL2.xml) and shallow-cloned via [`build.sh`](build.sh):

* **Device Trees:**
  * `device/nokia/PL2` ➔ [`Zoro-15/android_device_nokia_PL2`](https://github.com/Zoro-15/android_device_nokia_PL2) (`lineage-23.2`)
  * `device/nokia/sdm660-common` ➔ [`Zoro-15/android_device_nokia_sdm660-common`](https://github.com/Zoro-15/android_device_nokia_sdm660-common) (`lineage-23.2`)
* **Vendor Trees:**
  * `vendor/nokia/PL2` ➔ [`Zoro-15/proprietary_vendor_nokia_PL2`](https://github.com/Zoro-15/proprietary_vendor_nokia_PL2) (`lineage-23.2`)
  * `vendor/nokia/sdm660-common` ➔ [`Zoro-15/proprietary_vendor_nokia_sdm660-common`](https://github.com/Zoro-15/proprietary_vendor_nokia_sdm660-common) (`lineage-23.2`)
* **Kernel Tree:**
  * `kernel/nokia/sdm660` ➔ [`Zoro-15/android_kernel_nokia_PL2_16`](https://github.com/Zoro-15/android_kernel_nokia_PL2_16) (`lineage-23.2`) (4.4 base + 5.10 eBPF)
* **Qualcomm Hardware & SEPolicy HALs:**
  * `hardware/qcom-caf/sdm660/audio` ➔ [`Zoro-15/android_hardware_qcom_audio`](https://github.com/Zoro-15/android_hardware_qcom_audio) (`lineage-23.2`)
  * `hardware/qcom-caf/sdm660/display` ➔ [`Zoro-15/android_hardware_qcom_display`](https://github.com/Zoro-15/android_hardware_qcom_display) (`lineage-23.2-caf-msm8953`)
  * `hardware/qcom-caf/sdm660/media` ➔ [`Zoro-15/android_hardware_qcom_media`](https://github.com/Zoro-15/android_hardware_qcom_media) (`lineage-23.2-caf-msm8953`)
  * `device/qcom/sepolicy-legacy-um` ➔ [`Zoro-15/android_device_qcom_sepolicy`](https://github.com/Zoro-15/android_device_qcom_sepolicy) (`lineage-23.2`)
  * `hardware/lineage/compat` ➔ [`log1cs/android_hardware_lineage_compat`](https://github.com/log1cs/android_hardware_lineage_compat) (`lineage-23.2`)

---

## 🛠️ Local Usage

To run the exact same build logic locally on an Ubuntu / Debian machine:

```bash
# Clone the dryrunner
git clone -b A17-experiment https://github.com/Zoro-15/aosp-dryrunner.git
cd aosp-dryrunner

# Make executable and run dry-run
chmod +x build.sh
./build.sh nothing
```
