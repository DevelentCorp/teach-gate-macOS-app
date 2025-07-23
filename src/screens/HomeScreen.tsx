import React, {useState, useEffect} from 'react';
import {View, Text, StyleSheet, Pressable, Image} from 'react-native';
import ToggleSwitch from '../components/ToggleSwitch';
import {VpnService} from '../services/vpn';
import {VpnStatus} from '../services/types';

const vpnService = new VpnService();

interface Props {
  toggleSidebar: () => void;
  goToScreen: (screen: string) => void;
}

const HomeScreen: React.FC<Props> = ({toggleSidebar, goToScreen}) => {
  const [vpnStatus, setVpnStatus] = useState<VpnStatus>(VpnStatus.DISCONNECTED);
  const [time, setTime] = useState(0);

  useEffect(() => {
    const onStatusChanged = (status: VpnStatus) => setVpnStatus(status);
    vpnService.on('statusChanged', onStatusChanged);

    return () => {
      vpnService.off('statusChanged', onStatusChanged);
    };
  }, []);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (vpnStatus === VpnStatus.CONNECTED) {
      timer = setInterval(() => {
        setTime(prevTime => prevTime + 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [vpnStatus]);

  const toggleConnection = () => {
    if (vpnStatus === VpnStatus.CONNECTED) {
      vpnService.disconnect();
    } else if (vpnStatus === VpnStatus.DISCONNECTED) {
      vpnService.connect(
        'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTprQWVHaHF4WlI5UUlUZ21ZUUlZMk01@96.126.107.202:19834/?outline=1',
      ); // Key management to be implemented
    }
  };

  const formatTime = (seconds: number) => {
    const h = Math.floor(seconds / 3600)
      .toString()
      .padStart(2, '0');
    const m = Math.floor((seconds % 3600) / 60)
      .toString()
      .padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    return `${h} : ${m} : ${s}`;
  };

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
        <ToggleSwitch
          isOn={vpnStatus === VpnStatus.CONNECTED}
          onToggle={toggleConnection}
        />
        <Text style={styles.statusText}>
          {vpnStatus === VpnStatus.CONNECTED ? 'Connected' : 'Disconnected'}
        </Text>
        {vpnStatus === VpnStatus.CONNECTED && (
          <>
            <Text style={styles.timerText}>{formatTime(time)}</Text>
            <Text style={styles.ipText}>Your IP : 100.40.50.80</Text>
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
  liveTVText: {
    color: '#000',
    fontSize: 16,
    marginTop: 2,
    fontFamily: 'Poppins-Regular',
    fontWeight: '600',
  },
});

export default HomeScreen;
