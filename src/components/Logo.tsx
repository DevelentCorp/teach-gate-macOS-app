import React from 'react';
import {Image, StyleSheet} from 'react-native';

const Logo = () => {
  return (
    <Image source={require('../assets/images/Logo.png')} style={styles.logo} />
  );
};

const styles = StyleSheet.create({
  logo: {
    width: 300,
    height: 200,
    marginBottom: 20,
  },
});

export default Logo;
