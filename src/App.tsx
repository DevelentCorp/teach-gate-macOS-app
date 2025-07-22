import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import RootNavigator from './navigation/RootNavigator';
import {Platform} from 'react-native';

if (Platform.OS !== 'macos') {
  try {
    const {enableScreens} = require('react-native-screens');
    enableScreens();
  } catch (e) {
    console.warn('react-native-screens not available:', e);
  }
}

const App = () => {
  return (
    <NavigationContainer>
      <RootNavigator />
    </NavigationContainer>
  );
};

export default App;
