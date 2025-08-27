#!/usr/bin/env node

/**
 * VPN Toggle Debug Script - Diagnose VPN toggle switch issues in release build
 * This script validates the most likely root causes for VPN toggle failures
 */

const {exec} = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🔍 VPN Toggle Switch Diagnostic Tool');
console.log('=====================================\n');

async function runCommand(command, description) {
  return new Promise(resolve => {
    console.log(`🔧 ${description}...`);
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.log(`❌ Error: ${error.message}`);
        resolve({success: false, output: error.message});
        return;
      }
      if (stderr) {
        console.log(`⚠️  Warning: ${stderr}`);
      }
      if (stdout.trim()) {
        console.log(`✅ ${stdout.trim()}\n`);
        resolve({success: true, output: stdout.trim()});
      } else {
        console.log(`✅ Command executed successfully\n`);
        resolve({success: true, output: ''});
      }
    });
  });
}

async function diagnosePrimaryIssues() {
  console.log('🎯 PRIMARY DIAGNOSIS: OutlineAppleLib & Tun2socks Framework');
  console.log('============================================================');

  // Check if the built app exists
  const releaseBuild =
    '/Users/obedsayyad/teach-gate-macOS-app/build/Build/Products/Release/Teach Gate.app';
  const appExists = fs.existsSync(releaseBuild);

  if (!appExists) {
    console.log('❌ CRITICAL: Release build not found at expected path');
    console.log(`   Expected: ${releaseBuild}`);
    return 'build_not_found';
  }

  console.log('✅ Release build found');

  // Check if VPN extension is embedded
  const vpnExtensionPath = path.join(
    releaseBuild,
    'Contents/PlugIns/TeachGateVPN.appex',
  );
  const vpnExtensionExists = fs.existsSync(vpnExtensionPath);

  if (!vpnExtensionExists) {
    console.log('❌ CRITICAL: VPN extension not found in release build');
    return 'vpn_extension_missing';
  }

  console.log('✅ VPN extension embedded correctly');

  // Check for framework dependencies in the release build
  console.log('\n📦 Checking Framework Dependencies');
  console.log('==================================');

  const appFrameworksPath = path.join(releaseBuild, 'Contents/Frameworks');
  const vpnFrameworksPath = path.join(vpnExtensionPath, 'Contents/Frameworks');

  let tun2socksInApp = false;
  let tun2socksInVPN = false;

  if (fs.existsSync(appFrameworksPath)) {
    const appFrameworks = fs.readdirSync(appFrameworksPath);
    tun2socksInApp = appFrameworks.some(f => f.includes('Tun2socks'));
    console.log(`📁 App Frameworks: ${appFrameworks.join(', ')}`);
    console.log(
      `🔍 Tun2socks in App: ${tun2socksInApp ? '✅ Found' : '❌ Missing'}`,
    );
  }

  if (fs.existsSync(vpnFrameworksPath)) {
    const vpnFrameworks = fs.readdirSync(vpnFrameworksPath);
    tun2socksInVPN = vpnFrameworks.some(f => f.includes('Tun2socks'));
    console.log(`📁 VPN Extension Frameworks: ${vpnFrameworks.join(', ')}`);
    console.log(
      `🔍 Tun2socks in VPN Extension: ${
        tun2socksInVPN ? '✅ Found' : '❌ Missing'
      }`,
    );
  }

  if (!tun2socksInApp && !tun2socksInVPN) {
    console.log(
      '\n❌ CRITICAL ISSUE: Tun2socks framework missing from both app and VPN extension',
    );
    return 'tun2socks_missing';
  }

  // Check OutlineAppleLib Swift headers
  console.log('\n🧩 Checking OutlineAppleLib Integration');
  console.log('=====================================');

  const checkHeaders = await runCommand(
    `find "${releaseBuild}" -name "*OutlineTunnel*" -o -name "*OutlineAppleLib*" | head -10`,
    'Searching for OutlineAppleLib headers/modules in release build',
  );

  if (!checkHeaders.success || checkHeaders.output === '') {
    console.log(
      '❌ POTENTIAL ISSUE: No OutlineAppleLib components found in release build',
    );
    return 'outline_lib_missing';
  }

  return 'frameworks_present';
}

async function checkVPNToggleSpecifics() {
  console.log('\n🔄 VPN Toggle Specific Checks');
  console.log('=============================');

  // Check React Native bundle for TeachGateVPNModule
  const releaseBuild =
    '/Users/obedsayyad/teach-gate-macOS-app/build/Build/Products/Release/Teach Gate.app';
  const jsBundlePath = path.join(
    releaseBuild,
    'Contents/Resources/main.jsbundle',
  );

  if (fs.existsSync(jsBundlePath)) {
    console.log('✅ React Native bundle found');

    try {
      const bundleContent = fs.readFileSync(jsBundlePath, 'utf8');
      const hasVPNModule = bundleContent.includes('TeachGateVPNModule');
      console.log(
        `🔍 TeachGateVPNModule in bundle: ${
          hasVPNModule ? '✅ Found' : '❌ Missing'
        }`,
      );

      if (!hasVPNModule) {
        return 'rn_module_missing';
      }
    } catch (err) {
      console.log(`⚠️  Could not read JS bundle: ${err.message}`);
    }
  } else {
    console.log('❌ React Native bundle not found');
    return 'js_bundle_missing';
  }

  // Check code signing
  console.log('\n🔐 Code Signing Verification');
  console.log('============================');

  const codeSignCheck = await runCommand(
    `codesign -dv --verbose=4 "${releaseBuild}/Contents/PlugIns/TeachGateVPN.appex" 2>&1`,
    'Verifying VPN extension code signing',
  );

  if (!codeSignCheck.success) {
    return 'codesign_failed';
  }

  return 'toggle_checks_passed';
}

async function testVPNToggleFunctionality() {
  console.log('\n🧪 Testing VPN Toggle Response');
  console.log('==============================');

  // Check if we can connect to the app for testing (this would require the app to be running)
  console.log('💡 To test VPN toggle functionality:');
  console.log(
    '   1. Launch the release build: /Users/obedsayyad/teach-gate-macOS-app/build/Build/Products/Release/Teach Gate.app',
  );
  console.log('   2. Monitor console logs while testing toggle:');
  console.log(
    '      log stream --predicate \'subsystem CONTAINS "com.develentcorp.teachgatedesk"\'',
  );
  console.log('   3. Look for these specific error patterns:');
  console.log('      - "missing_outlinelib" - OutlineAppleLib not linked');
  console.log(
    '      - "Tun2socks framework not available" - Framework import failed',
  );
  console.log(
    '      - "Invalid NETunnelNetworkSettings" - Network configuration issues',
  );

  return 'manual_testing_required';
}

async function provideDiagnosis(primaryResult, toggleResult, testResult) {
  console.log('\n🎯 DIAGNOSIS & RECOMMENDATIONS');
  console.log('==============================');

  switch (primaryResult) {
    case 'build_not_found':
      console.log('❌ ROOT CAUSE: Release build not found');
      console.log('🔧 SOLUTION: Rebuild the project for Release configuration');
      break;

    case 'vpn_extension_missing':
      console.log('❌ ROOT CAUSE: VPN extension not embedded in release build');
      console.log(
        '🔧 SOLUTION: Check Xcode project "Embed Foundation Extensions" build phase',
      );
      break;

    case 'tun2socks_missing':
      console.log(
        '❌ ROOT CAUSE: Tun2socks framework not linked to VPN extension',
      );
      console.log('🔧 SOLUTIONS:');
      console.log('   1. In Xcode, select TeachGateVPN target');
      console.log('   2. Build Phases → Link Binary With Libraries');
      console.log('   3. Add Tun2socks.xcframework');
      console.log(
        '   4. Ensure "Copy Frameworks VPN" phase includes Tun2socks',
      );
      console.log('   5. Clean and rebuild');
      break;

    case 'outline_lib_missing':
      console.log(
        '❌ ROOT CAUSE: OutlineAppleLib not properly integrated in release build',
      );
      console.log('🔧 SOLUTIONS:');
      console.log('   1. Check Swift Package Manager dependencies in Xcode');
      console.log(
        '   2. Ensure OutlineAppleLib is linked to both app and VPN extension targets',
      );
      console.log(
        '   3. Verify Package.resolved contains correct OutlineAppleLib resolution',
      );
      console.log('   4. Clean DerivedData and rebuild');
      break;

    case 'frameworks_present':
      console.log('✅ Frameworks appear to be present');
      if (toggleResult === 'rn_module_missing') {
        console.log(
          '❌ SECONDARY ISSUE: TeachGateVPNModule missing from React Native bundle',
        );
        console.log(
          '🔧 SOLUTION: Check React Native metro bundler configuration',
        );
      } else if (toggleResult === 'codesign_failed') {
        console.log('❌ SECONDARY ISSUE: Code signing problems');
        console.log(
          '🔧 SOLUTION: Re-sign the VPN extension with proper entitlements',
        );
      } else {
        console.log(
          '⚠️  RUNTIME ISSUE: Frameworks present but toggle not working',
        );
        console.log(
          '🔧 NEXT STEPS: Run the app and check console logs for runtime errors',
        );
      }
      break;

    default:
      console.log('⚠️  Unknown diagnostic result');
  }

  console.log('\n📋 VALIDATION STEPS:');
  console.log('1. Launch the release app');
  console.log(
    '2. Open Console.app and filter for "teachgate" or "develentcorp"',
  );
  console.log('3. Try toggling VPN switch');
  console.log('4. Look for specific error messages mentioned above');
  console.log('5. If errors found, apply corresponding solutions');
}

async function main() {
  const primaryResult = await diagnosePrimaryIssues();
  const toggleResult = await checkVPNToggleSpecifics();
  const testResult = await testVPNToggleFunctionality();

  await provideDiagnosis(primaryResult, toggleResult, testResult);

  console.log('\n📞 Summary:');
  console.log(`Primary Diagnosis: ${primaryResult}`);
  console.log(`Toggle Check: ${toggleResult}`);
  console.log(`Test Result: ${testResult}`);
}

main().catch(console.error);
