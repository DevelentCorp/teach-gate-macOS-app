import React, {useState, useEffect} from 'react';
import {View, Text, StyleSheet, Pressable, Image, Platform} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {Buffer} from 'buffer';
import ToggleSwitch from '../components/ToggleSwitch';
// @ts-ignore - Will be available after linking
import OutlineVpn from 'react-native-outline-vpn';

interface Props {
  toggleSidebar: () => void;
  goToScreen: (screen: string) => void;
}

const CONNECTION_START_KEY = 'vpnConnectionStartTime';

const HomeScreen: React.FC<Props> = ({toggleSidebar, goToScreen}) => {
  const [isConnected, setIsConnected] = useState(false);
  const [connectionTime, setConnectionTime] = useState({
    hours: 0,
    minutes: 0,
    seconds: 0,
  });
  const [loading, setLoading] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [vpnConfig, setVpnConfig] = useState<any>(null);

  const calculateElapsed = async () => {
    const startTimeStr = await AsyncStorage.getItem(CONNECTION_START_KEY);
    if (startTimeStr) {
      const startTime = parseInt(startTimeStr, 10);
      const now = Date.now();
      const diffSeconds = Math.floor((now - startTime) / 1000);
      const hours = Math.floor(diffSeconds / 3600);
      const minutes = Math.floor((diffSeconds % 3600) / 60);
      const seconds = diffSeconds % 60;
      setConnectionTime({hours, minutes, seconds});
    }
  };

  useEffect(() => {
    const checkVpnStatus = async () => {
      try {
        if (Platform.OS === 'macos') {
          const status = await OutlineVpn.getVpnStatus();
          setIsConnected(status);
          if (status) {
            calculateElapsed();
          }
        }
      } catch (err) {
        console.warn('Could not check VPN status', err);
      }
    };
    checkVpnStatus();
  }, []);

  useEffect(() => {
    let interval: any;
    if (isConnected) {
      calculateElapsed(); // initial sync
      interval = setInterval(() => {
        calculateElapsed();
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isConnected]);

  const parseAccessUrl = (accessUrl: string) => {
    try {
      if (
        !accessUrl.startsWith(
          'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpCTE5zbXhBUTFmdVVsMndVWUtGcFNq@96.126.107.202:19834/?outline=1',
        )
      )
        throw new Error('Invalid Shadowsocks URL');
      const cleaned = accessUrl.replace('ss://', '');
      const [base64Part, addressPart] = cleaned.split('@');
      if (!base64Part || !addressPart) throw new Error('Malformed URL');

      // For macOS we need to decode properly
      const decoded = Buffer.from(base64Part, 'base64').toString('utf-8');
      const [method, password] = decoded.split(':');
      const [host, portStr] = addressPart.split(':');
      const port = parseInt(portStr, 10);

      return {
        host,
        port,
        password,
        method,
        prefix: '\u0005\u00DC\u005F\u00E0\u0001\u0020',
        providerBundleIdentifier: 'com.develentcorp.teachgatedesk.tgvpn',
        serverAddress: 'TeachGateServer',
        tunnelId: 'TeachGateServer',
        localizedDescription: 'Teach Gate VPN',
      };
    } catch (err) {
      console.warn('Failed to parse accessUrl:', err);
      return null;
    }
  };

  const toggleConnection = async () => {
    if (Platform.OS !== 'macos') {
      // Fallback for non-macOS platforms
      setIsConnected(prev => !prev);
      return;
    }

    try {
      setConnecting(true);

      if (isConnected) {
        // Disconnect VPN with delay (8s)
        setTimeout(async () => {
          await OutlineVpn.stopVpn();
          setIsConnected(false);
          await AsyncStorage.removeItem(CONNECTION_START_KEY);
          setConnectionTime({hours: 0, minutes: 0, seconds: 0});
          setConnecting(false);
        }, 8000);
      } else {
        // ✅ Use your Shadowsocks access URL
        const accessUrl =
          'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpCTE5zbXhBUTFmdVVsMndVWUtGcFNq@96.126.107.202:19834/?outline=1';

        const config = parseAccessUrl(accessUrl);
        if (!config) {
          throw new Error('Invalid VPN config');
        }

        await OutlineVpn.startVpn(config);
        await AsyncStorage.setItem(CONNECTION_START_KEY, Date.now().toString());
        setIsConnected(true);
        setConnectionTime({hours: 0, minutes: 0, seconds: 0});
        setConnecting(false);
      }
    } catch (err) {
      console.error('Error toggling VPN:', err);
      setConnecting(false);
    }
  };

  const formatTime = (value: number) => value.toString().padStart(2, '0');

  return (
    <View style={styles.container}>
      <Pressable onPress={toggleSidebar} style={styles.menuButton}>
        <Text style={{fontSize: 30, color: '#2A66EA'}}>☰</Text>
      </Pressable>

      <View style={styles.header}>
        <Image
          source={require('../assets/images/shield.jpg')}
          style={styles.shield}
        />
        <View>
          <Text style={styles.heading}>TEACH GATE</Text>
          <Text style={styles.subheading}>CONNECT</Text>
        </View>
      </View>

      <View style={styles.statusContainer}>
        <ToggleSwitch isOn={isConnected} onToggle={toggleConnection} />
        <Text style={styles.statusText}>
          {isConnected ? 'Connected' : 'Disconnected'}
        </Text>
        {connecting && (
          <Text style={styles.connectingText}>
            Establishing secure connection...
          </Text>
        )}
        {isConnected && (
          <>
            <Text style={styles.timerText}>
              {formatTime(connectionTime.hours)}:
              {formatTime(connectionTime.minutes)}:
              {formatTime(connectionTime.seconds)}
            </Text>
            <Text style={styles.ipText}>Your Connection is Secure</Text>
          </>
        )}
      </View>

      {/* Live TV Button */}
      <Pressable
        onPress={() => goToScreen('LiveTV')}
        style={styles.liveTVButton}>
        <Image
          source={require('../assets/images/logo-icon.png')}
          style={{width: 20, height: 24, marginRight: 10}}
        />
        <Text style={styles.liveTVText}>Live TV</Text>
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    paddingTop: 80,
    backgroundColor: '#fff',
  },
  menuButton: {
    position: 'absolute',
    top: 40,
    left: 20,
    backgroundColor: '#fff',
    padding: 10,
    borderRadius: 30,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.3,
    shadowRadius: 4,
    zIndex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 20,
    marginTop: 40,
  },
  shield: {
    width: 80,
    height: 90,
    marginBottom: 10,
    marginRight: 20,
  },
  heading: {
    fontSize: 45,
    fontFamily: 'Poppins-Bold',
    fontWeight: '700',
    color: '#00456A',
    textAlign: 'center',
  },
  subheading: {
    fontSize: 45,
    fontFamily: 'Poppins-Bold',
    fontWeight: '700',
    color: '#CA2611',
    marginLeft: 26,
  },
  statusContainer: {
    alignItems: 'center',
    marginTop: 50,
  },
  statusText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#0B2838',
    marginTop: 20,
  },
  timerText: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#000',
    marginTop: 20,
  },
  ipText: {
    fontSize: 18,
    color: '#000',
    marginTop: 10,
  },
  liveTVButton: {
    position: 'absolute',
    bottom: 30,
    right: 30,
    flexDirection: 'row',
    backgroundColor: '#fff',
    paddingVertical: 10,
    height: 50,
    width: 150,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
    borderRadius: 30,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  connectingText: {
    fontSize: 16,
    color: '#555',
    fontStyle: 'italic',
    textAlign: 'center',
    marginBottom: 20,
  },
  liveTVText: {
    color: '#000',
    fontSize: 16,
    marginTop: 2,
    fontFamily: 'Poppins-Regular',
    fontWeight: '600',
  },
});

export default HomeScreen;
