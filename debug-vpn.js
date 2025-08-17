#!/usr/bin/env node

const {exec} = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🔍 TeachGate VPN Debug Script');
console.log('=====================================\n');

// Function to run shell commands
function runCommand(command, description) {
  return new Promise((resolve, reject) => {
    console.log(`🔧 ${description}...`);
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.log(`❌ Error: ${error.message}`);
        resolve(false);
        return;
      }
      if (stderr) {
        console.log(`⚠️  Warning: ${stderr}`);
      }
      if (stdout.trim()) {
        console.log(`✅ ${stdout.trim()}\n`);
      } else {
        console.log(`✅ Command executed successfully\n`);
      }
      resolve(true);
    });
  });
}

async function debugVPN() {
  console.log('1. Checking System VPN Configurations');
  console.log('=====================================');
  await runCommand('scutil --nc list', 'Listing VPN configurations');

  console.log('2. Checking Network Extension Status');
  console.log('=====================================');
  await runCommand('systemextensionsctl list', 'Listing system extensions');

  console.log('3. Checking App Group Container');
  console.log('=====================================');
  const homeDir = process.env.HOME;
  const appGroupPath = path.join(
    homeDir,
    'Library/Group Containers/group.com.teachgate.vpn',
  );

  try {
    if (fs.existsSync(appGroupPath)) {
      console.log(`✅ App Group container exists: ${appGroupPath}`);
      const configPath = path.join(appGroupPath, 'vpn-config.json');
      if (fs.existsSync(configPath)) {
        console.log('✅ VPN config file exists');
        const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        console.log(
          `📋 Config: Host=${config.host}, Port=${config.port}, Method=${config.method}\n`,
        );
      } else {
        console.log('❌ VPN config file not found\n');
      }
    } else {
      console.log('❌ App Group container not found\n');
    }
  } catch (error) {
    console.log(`❌ Error checking App Group: ${error.message}\n`);
  }

  console.log('4. Checking Console Logs for VPN Activity');
  console.log('=========================================');
  await runCommand(
    'log show --last 5m --predicate \'subsystem CONTAINS "com.teachgate.vpn"\' --info',
    'Recent VPN logs',
  );

  console.log('5. Checking Network Extension Logs');
  console.log('==================================');
  await runCommand(
    'log show --last 5m --predicate \'category == "PacketTunnelProvider"\' --info',
    'Network Extension logs',
  );

  console.log('6. Testing Network Connectivity');
  console.log('===============================');
  await runCommand(
    'curl -s --max-time 5 https://api.ipify.org',
    'Current public IP',
  );
  await runCommand('ping -c 1 8.8.8.8', 'DNS connectivity test');

  console.log('🎯 Debug Summary');
  console.log('================');
  console.log('If VPN is not connecting, check:');
  console.log(
    '• Network Extension permissions in System Preferences > Security & Privacy',
  );
  console.log('• VPN configuration in System Preferences > Network');
  console.log('• Console logs for detailed error messages');
  console.log(
    '• Ensure TeachGateVPN extension is properly signed and installed',
  );
  console.log('\nFor real-time monitoring, run:');
  console.log(
    'log stream --predicate \'subsystem CONTAINS "com.teachgate.vpn"\'',
  );
}

debugVPN().catch(console.error);
