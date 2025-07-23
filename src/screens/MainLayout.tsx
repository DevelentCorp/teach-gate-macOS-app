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
  const [sidebarVisible, setSidebarVisible] = useState(false);

  const toggleSidebar = () => setSidebarVisible(prev => !prev);

  const goToScreen = (screen: 'Home' | 'LiveTV' | 'Account') => {
    setCurrentScreen(screen);
    setSidebarVisible(false);
  };

  const renderCurrentScreen = () => {
    const screenProps = {toggleSidebar, goToScreen};

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
            goToScreen(screen as 'Home' | 'LiveTV' | 'Account')
          }
          selected={currentScreen}
          onClose={() => setSidebarVisible(false)}
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
