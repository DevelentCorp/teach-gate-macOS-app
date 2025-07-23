import React from 'react';
import {View, StyleSheet, Pressable, Text} from 'react-native';
import {WebView} from 'react-native-webview';

type LiveTVScreenProps = {
  toggleSidebar: () => void;
};

const LiveTVScreen: React.FC<LiveTVScreenProps> = ({toggleSidebar}) => {
  const injectedCSS = `
  (function() {
    const style = document.createElement('style');
    style.innerHTML = \`
      header, .navbar, .menu, .logo, .site-header {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
      }
      #back-to-country-list-button {
        background-color: white !important;
        color: white !important;
      }
      body {
        padding-top: 0 !important;
        margin-top: 0 !important;
      }
    \`;
    document.head.appendChild(style);
  })();
  true;
`;
  return (
    <View style={styles.container}>
      <View style={{height: 60}}>
        <Pressable onPress={toggleSidebar} style={styles.menuButton}>
          <Text style={styles.menuText}>{'\u2190'}</Text>
          <Text
            style={{
              fontSize: 20,
              color: 'white',
              fontWeight: '600',
              marginTop: -5,
            }}>
            Teach Gate Live
          </Text>
        </Pressable>
      </View>
      <WebView
        source={{uri: 'https://tv.garden'}}
        injectedJavaScript={injectedCSS}
        javaScriptEnabled
        domStorageEnabled
        style={styles.webview}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'black',
    zIndex: 4,
  },
  webview: {
    zIndex: 1,
    marginTop: -70,
  },
  menuButton: {
    position: 'absolute',
    top: 20,
    left: 20,
    zIndex: 10,
    flexDirection: 'row',
    backgroundColor: 'black',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 25,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  menuText: {
    fontSize: 20,
    color: '#00456A',
    borderRadius: 10,
    padding: 5,
    marginBottom: 15,
    marginTop: -10,
    marginRight: 10,
    fontWeight: '600',
    backgroundColor: 'white',
  },
});

export default LiveTVScreen;
