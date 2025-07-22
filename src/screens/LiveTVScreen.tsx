import React from 'react';
import {View, StyleSheet, Pressable, Text} from 'react-native';
import {WebView} from 'react-native-webview';

type LiveTVScreenProps = {
  toggleSidebar: () => void;
};

const LiveTVScreen: React.FC<LiveTVScreenProps> = ({toggleSidebar}) => {
  return (
    <View style={styles.container}>
      <Pressable onPress={toggleSidebar} style={styles.menuButton}>
        <Text style={styles.menuText}>☰</Text>
      </Pressable>
      <WebView source={{uri: 'https://tv.garden'}} style={styles.webview} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  webview: {
    flex: 1,
    marginTop: 60, // leave space for menu button
  },
  menuButton: {
    position: 'absolute',
    top: 20,
    left: 20,
    zIndex: 10,
    backgroundColor: 'white',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 5,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  menuText: {
    fontSize: 20,
  },
});

export default LiveTVScreen;
