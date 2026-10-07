#!/usr/bin/env bash
# =============================================================================
#  LineageOS 23.2 (Android 16) Build & Fast Error-Probing Dry-Runner for PL2
# =============================================================================
set -e

TARGET="${1:-nothing}"
CLEAN="${2:-false}"
START_TIME=$(date +%s)
ORIGIN_DIR=""

echo "====================================================================="
echo " LineageOS 23.2 Fast Error-Probing Runner — Nokia 6.1 (PL2)"
echo " Target : $TARGET"
echo " Clean  : $CLEAN"
echo "====================================================================="

# 0. Transparent BTRFS Storage Redirection (if present)
if [ -d "/mnt/android" ]; then
    echo "--> Transparent BTRFS compressed volume detected (/mnt/android)."
    ORIGIN_DIR="$(pwd)"
    mkdir -p /mnt/android/workspace
    cp -r manifests /mnt/android/workspace/ 2>/dev/null || true
    cd /mnt/android/workspace
fi

# 1. Environment & Memory Guards
echo "--> Configuring build environment..."
export GOMEMLIMIT=12GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx8g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export DISABLE_DEXPREOPT_CHECK=true
export WITH_DEXPREOPT=false
unset WITHOUT_CHECK_API
export WITHOUT_CHECK_API=false
unset SKIP_ABI_CHECKS

# 2. Pre-flight tree cleanup
echo "--> Cleaning stale device trees and manifests..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common
rm -rf vendor/nokia/PL2 vendor/nokia/sdm660-common
rm -rf kernel/nokia/sdm660
rm -rf hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
rm -rf device/qcom/sepolicy-legacy-um hardware/lineage/compat

# 3. Base Manifest initialization & Local Manifest deployment
echo "--> Initializing LineageOS 23.2 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

echo "--> Deploying PL2 local manifest..."
mkdir -p .repo/local_manifests
if [ -f "manifests/PL2.xml" ]; then
    cp manifests/PL2.xml .repo/local_manifests/PL2.xml
else
    cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remove-project name="LineageOS/android_hardware_qcom_audio" />
  <remove-project name="LineageOS/android_hardware_qcom_display" />
  <remove-project name="LineageOS/android_hardware_qcom_media" />
  <remove-project name="LineageOS/android_device_qcom_sepolicy" />
  <remove-project name="LineageOS/android_hardware_lineage_compat" />

  <project path="device/nokia/sdm660-common" name="Zoro-15/android_device_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/sdm660-common" name="Zoro-15/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/PL2" name="Zoro-15/proprietary_vendor_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="kernel/nokia/sdm660" name="Zoro-15/android_kernel_nokia_PL2_16" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/audio" name="Zoro-15/android_hardware_qcom_audio" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/display" name="Zoro-15/android_hardware_qcom_display" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="hardware/qcom-caf/sdm660/media" name="Zoro-15/android_hardware_qcom_media" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="device/qcom/sepolicy-legacy-um" name="Zoro-15/android_device_qcom_sepolicy" remote="github" revision="lineage-23.2" />
  <project path="hardware/lineage/compat" name="log1cs/android_hardware_lineage_compat" remote="github" revision="lineage-23.2" />
</manifest>
EOF
fi

# 4. Sync source repositories
echo "--> Syncing source repositories..."
set +e
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
fi
set -e

# 5. Fallback clones (ensure all 10 trees exist)
echo "--> Verifying device and hardware trees..."
[ ! -d "device/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
[ ! -d "device/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
[ ! -d "vendor/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_sdm660-common.git vendor/nokia/sdm660-common
[ ! -d "vendor/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_PL2.git vendor/nokia/PL2
[ ! -d "kernel/nokia/sdm660" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_kernel_nokia_PL2_16.git kernel/nokia/sdm660
[ ! -d "hardware/qcom-caf/sdm660/audio" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_hardware_qcom_audio.git hardware/qcom-caf/sdm660/audio
[ ! -d "hardware/qcom-caf/sdm660/display" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_display.git hardware/qcom-caf/sdm660/display
[ ! -d "hardware/qcom-caf/sdm660/media" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_media.git hardware/qcom-caf/sdm660/media
[ ! -d "device/qcom/sepolicy-legacy-um" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_qcom_sepolicy.git device/qcom/sepolicy-legacy-um
[ ! -d "hardware/lineage/compat" ] && git clone --depth=1 -b lineage-23.2 https://github.com/log1cs/android_hardware_lineage_compat.git hardware/lineage/compat

# 5b. Post-sync storage reclamation (Zephyr's .repo purge technique)
echo "--> Reclaiming storage: purging .repo/ git caches (frees ~20 GB)..."
rm -rf .repo/

# 6. Soong namespaces setup
mkdir -p hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
[ ! -f "hardware/qcom-caf/sdm660/Android.bp" ] && echo "soong_namespace {}" > hardware/qcom-caf/sdm660/Android.bp
[ ! -f "hardware/qcom-caf/msm8998/Android.bp" ] && echo "soong_namespace {}" > hardware/qcom-caf/msm8998/Android.bp

# 7. CCACHE setup
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(command -v ccache)"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
elif [ -x "prebuilts/misc/linux-x86/ccache/ccache" ]; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(pwd)/prebuilts/misc/linux-x86/ccache/ccache"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
fi

# 8. Environment Setup & Lunch Target
source build/envsetup.sh
if lunch lineage_PL2-ap4a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-ap4a-userdebug"
elif lunch lineage_PL2-bp1a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-bp1a-userdebug"
elif lunch lineage_PL2-userdebug; then
    echo "--> Selected lunch target: lineage_PL2-userdebug"
else
    echo "[FATAL] Lunch failed!"
    exit 1
fi

# 9. Optional Clean
if [ "$CLEAN" = "true" ]; then
    echo "--> Running make clean..."
    make clean || true
else
    echo "--> Running installclean..."
    make installclean || true
fi

# 10. Execute Target & Capture Errors
echo "--> Executing target: $TARGET"
set +e
BUILD_STATUS=0
if [ "$TARGET" = "all-sequential" ]; then
    echo "--> Running all error-probing targets sequentially in fast-fail order..."
    for SUB_TARGET in "nothing" "selinux_policy" "bootimage" "vendorimage"; do
        echo ""
        echo "====================================================================="
        echo " [STAGE] Probing Target: $SUB_TARGET"
        echo "====================================================================="
        if [ "$SUB_TARGET" = "nothing" ]; then
            m nothing -j$(nproc --all) 2>&1 | tee -a build_a16_PL2.log
        else
            mka "$SUB_TARGET" -j$(nproc --all) 2>&1 | tee -a build_a16_PL2.log
        fi
        STAGE_STATUS=${PIPESTATUS[0]}
        if [ $STAGE_STATUS -ne 0 ]; then
            echo "[!] Stage $SUB_TARGET failed with exit code $STAGE_STATUS!"
            BUILD_STATUS=$STAGE_STATUS
            break
        fi
        echo "[✓] Stage $SUB_TARGET passed!"
    done
elif [ "$TARGET" = "nothing" ]; then
    echo "--> Probing Soong analysis, Blueprint syntax & SEPolicy graph (m nothing)..."
    m nothing -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
    BUILD_STATUS=${PIPESTATUS[0]}
elif [ "$TARGET" = "bootimage" ]; then
    echo "--> Compiling kernel 4.4 + DTBO + ramdisk (mka bootimage)..."
    mka bootimage -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
    BUILD_STATUS=${PIPESTATUS[0]}
elif [ "$TARGET" = "vendorimage" ]; then
    echo "--> Compiling Qualcomm CAF HALs & vendor partition (mka vendorimage)..."
    mka vendorimage -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
    BUILD_STATUS=${PIPESTATUS[0]}
elif [ "$TARGET" = "selinux_policy" ]; then
    echo "--> Auditing and compiling SELinux policy rules (mka selinux_policy)..."
    mka selinux_policy -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
    BUILD_STATUS=${PIPESTATUS[0]}
else
    echo "--> Compiling custom / full target ($TARGET)..."
    mka "$TARGET" -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
    BUILD_STATUS=${PIPESTATUS[0]}
fi
set -e

# Sync artifacts back to origin workspace if redirected
if [ -n "$ORIGIN_DIR" ]; then
    cp build_a16_PL2.log "$ORIGIN_DIR/" 2>/dev/null || true
    mkdir -p "$ORIGIN_DIR/out/target/product/PL2" 2>/dev/null || true
    cp -r out/target/product/PL2/*.img "$ORIGIN_DIR/out/target/product/PL2/" 2>/dev/null || true
    cp -r out/target/product/PL2/*.zip "$ORIGIN_DIR/out/target/product/PL2/" 2>/dev/null || true
fi

# 11. Error Extraction & Reporting
if [ $BUILD_STATUS -ne 0 ]; then
    echo ""
    echo "====================================================================="
    echo " [!] BUILD FAILED (Exit Code: $BUILD_STATUS) — ERROR EXTRACTION"
    echo "====================================================================="
    grep -E -A 2 -B 1 "FAILED:|error:|fatal error:|ninja: error:|neverallow" build_a16_PL2.log | tail -n 50 || true
    echo "====================================================================="
    echo " Full log saved in: build_a16_PL2.log"
    echo "====================================================================="
    exit $BUILD_STATUS
fi

# 12. Success Summary
echo ""
echo "====================================================================="
echo " [✓] Build Completed Successfully (0 Errors)"
echo "====================================================================="
if [ -f "out/target/product/PL2/boot.img" ]; then
    echo "[ARTIFACT] boot.img: $(ls -lh out/target/product/PL2/boot.img | awk '{print $5}')"
fi
if [ -f "out/target/product/PL2/vendor.img" ]; then
    echo "[ARTIFACT] vendor.img: $(ls -lh out/target/product/PL2/vendor.img | awk '{print $5}')"
fi
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1 || true)
if [ -n "$OUT_ZIP" ] && [ -f "$OUT_ZIP" ]; then
    echo "[ARTIFACT] ROM ZIP: $OUT_ZIP ($(ls -lh "$OUT_ZIP" | awk '{print $5}'))"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Elapsed Time: $((ELAPSED / 60))m $((ELAPSED % 60))s ==="
