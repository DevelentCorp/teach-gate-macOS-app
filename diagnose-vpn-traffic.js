#!/usr/bin/env node

const {exec} = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🔍 VPN Traffic Diagnosis Tool');
console.log('==============================\n');

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

async function diagnoseTunnel() {
  console.log('1. 🚇 Checking VPN Connection Status');
  console.log('=====================================');

  // Check if VPN is connected
  const vpnStatus = await runCommand(
    'scutil --nc list | grep "com.teachgatedesk.develentcorp"',
    'Checking VPN status',
  );

  if (!vpnStatus.success || !vpnStatus.output.includes('Connected')) {
    console.log('❌ VPN is not connected! This could be the root cause.\n');
    return false;
  }

  console.log('✅ VPN shows as connected\n');
  return true;
}

async function checkNetworkExtension() {
  console.log('2. 🔧 Checking Network Extension');
  console.log('=================================');

  // Check system extensions
  await runCommand(
    'systemextensionsctl list | grep -i teach',
    'Checking system extensions',
  );

  // Check running processes
  await runCommand(
    'ps aux | grep -i teachgate | grep -v grep',
    'Checking running processes',
  );

  return true;
}

async function analyzeTraffic() {
  console.log('3. 📊 Analyzing Network Traffic');
  console.log('===============================');

  // Check current IP
  const ipResult = await runCommand(
    'curl -s --max-time 5 https://api.ipify.org',
    'Getting current public IP',
  );

  if (ipResult.success && ipResult.output) {
    console.log(`🌐 Current public IP: ${ipResult.output}`);

    // Check if this matches the VPN server IP
    const expectedVpnIP = '96.126.107.202'; // From the Shadowsocks config
    if (ipResult.output.trim() === expectedVpnIP) {
      console.log('✅ IP matches VPN server - traffic is being routed!\n');
      return true;
    } else {
      console.log(
        '❌ IP does not match VPN server - traffic is NOT being routed!\n',
      );
      return false;
    }
  } else {
    console.log('❌ Cannot reach internet - complete connectivity failure\n');
    return false;
  }
}

async function checkLogs() {
  console.log('4. 📋 Analyzing Recent VPN Logs');
  console.log('===============================');

  // Get recent VPN logs
  await runCommand(
    'log show --last 2m --predicate \'subsystem CONTAINS "TeachGateVPN"\' --style compact',
    'Getting recent Network Extension logs',
  );

  console.log('\n5. 🔍 Key Diagnostic Questions');
  console.log('==============================');

  // Look for specific log patterns
  const logCheck = await runCommand(
    'log show --last 5m --predicate \'subsystem CONTAINS "TeachGateVPN"\' | grep -E "(Tun2socks|CRITICAL|framework not available|fallback)"',
    'Checking for Tun2socks availability',
  );

  if (logCheck.success && logCheck.output.includes('framework not available')) {
    console.log(
      '🚨 CRITICAL ISSUE FOUND: Tun2socks framework is not available!',
    );
    console.log(
      '📝 This means the Network Extension is missing the Tun2socks dependency.',
    );
    console.log(
      '🔧 SOLUTION: The Network Extension target needs to link the Tun2socks framework.\n',
    );
    return 'missing_tun2socks';
  } else if (
    logCheck.success &&
    logCheck.output.includes('Tun2socks framework available')
  ) {
    console.log('✅ Tun2socks framework is available');
    console.log(
      '🔍 Issue is likely in packet routing or Shadowsocks connectivity\n',
    );
    return 'tun2socks_available';
  } else {
    console.log('⚠️  No clear Tun2socks status found in logs\n');
    return 'unclear';
  }
}

async function testConnectivity() {
  console.log('6. 🌐 Testing Basic Connectivity');
  console.log('=================================');

  // Test DNS resolution
  await runCommand('nslookup google.com 1.1.1.1', 'Testing DNS resolution');

  // Test direct connection to Shadowsocks server
  await runCommand(
    'nc -z -v 96.126.107.202 19834 2>&1 || echo "Connection failed"',
    'Testing Shadowsocks server connectivity',
  );

  // Test basic HTTP connectivity
  await runCommand(
    'curl -s --max-time 5 -I https://www.google.com | head -1',
    'Testing HTTP connectivity',
  );
}

async function provideSolution(diagnosticResult) {
  console.log('🎯 DIAGNOSIS RESULTS');
  console.log('====================');

  switch (diagnosticResult) {
    case 'missing_tun2socks':
      console.log(
        '❌ ROOT CAUSE: Tun2socks framework is not linked to Network Extension',
      );
      console.log('');
      console.log('🔧 SOLUTION STEPS:');
      console.log('1. Open Xcode project');
      console.log('2. Select TeachGateVPN Network Extension target');
      console.log('3. Go to Build Phases → Link Binary With Libraries');
      console.log('4. Add Tun2socks.framework');
      console.log('5. Rebuild and reinstall the app');
      console.log('');
      console.log(
        '📝 Alternative: The PacketTunnelProvider is using #if canImport(Tun2socks)',
      );
      console.log(
        '   and falling back to basic packet processing that drops packets.',
      );
      break;

    case 'tun2socks_available':
      console.log('🔍 Tun2socks is available, but traffic is not routing');
      console.log('');
      console.log('🔧 POSSIBLE CAUSES:');
      console.log('1. Shadowsocks server is unreachable');
      console.log('2. Incorrect Shadowsocks credentials');
      console.log('3. Packet processing logic issues');
      console.log('4. Network routing configuration problems');
      console.log('');
      console.log(
        '📝 Check the detailed logs above for Shadowsocks connection errors',
      );
      break;

    default:
      console.log('⚠️  Unable to determine root cause from logs');
      console.log('');
      console.log('🔧 NEXT STEPS:');
      console.log('1. Connect to VPN and immediately run:');
      console.log(
        '   log stream --predicate \'subsystem CONTAINS "TeachGateVPN"\'',
      );
      console.log('2. Look for "Tun2socks framework" messages');
      console.log('3. Check for "CRITICAL" or "fallback" messages');
      console.log('4. Verify Shadowsocks server connectivity');
  }
}

async function main() {
  const isConnected = await diagnoseTunnel();

  if (!isConnected) {
    console.log('🚨 VPN is not connected - this is the primary issue!');
    console.log(
      '🔧 First fix the VPN connection, then diagnose traffic routing.',
    );
    return;
  }

  await checkNetworkExtension();
  const trafficRouted = await analyzeTraffic();
  const diagnosticResult = await checkLogs();
  await testConnectivity();

  await provideSolution(diagnosticResult);

  if (!trafficRouted) {
    console.log('\n🚨 SUMMARY: VPN connects but traffic is NOT being routed');
    console.log(
      'This confirms there is a packet processing issue in the Network Extension.',
    );
  }
}

main().catch(console.error);
