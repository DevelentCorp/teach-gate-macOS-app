import React, {useState} from 'react';
import {View, StyleSheet} from 'react-native';
import Sidebar from '../components/Sidebar';
import HomeScreen from './HomeScreen';
import LiveTVScreen from './LiveTVScreen';
import AccountScreen from './AccountScreen';

const MainLayout = () => {
  const [currentScreen, setCurrentScreen] = useState<
    'Home' | 'LiveTV' | 'Account'
  >('Home');
  const [sidebarVisible, setSidebarVisible] = useState(true);

  const toggleSidebar = () => setSidebarVisible(prev => !prev);

  const renderCurrentScreen = () => {
    const screenProps = {toggleSidebar};

    switch (currentScreen) {
      case 'Home':
        return <HomeScreen {...screenProps} />;
      case 'LiveTV':
        return <LiveTVScreen {...screenProps} />;
      case 'Account':
        return <AccountScreen {...screenProps} />;
      default:
        return <HomeScreen {...screenProps} />;
    }
  };

  return (
    <View style={styles.container}>
      {sidebarVisible && (
        <Sidebar
          onSelect={(screen: string) =>
            setCurrentScreen(screen as 'Home' | 'LiveTV' | 'Account')
          }
          selected={currentScreen}
        />
      )}
      <View style={styles.content}>{renderCurrentScreen()}</View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: '#fff',
  },
  content: {
    flex: 1,
    backgroundColor: '#fff',
  },
});

export default MainLayout;
