import React from 'react';
import {View, Text, Image, StyleSheet, Pressable, Platform} from 'react-native';

const OnboardingScreen = ({navigation}: {navigation: any}) => {
  return (
    <View style={styles.container}>
      <Text style={[styles.heading, {fontFamily: 'Poppins-Regular'}]}>
        Trusted security
      </Text>
      <Text style={styles.subheading}>
        <Text style={styles.bold}>with One Tap</Text>
      </Text>
      <Text style={styles.description}>
        keep your data private and{'\n'}secure every time you connect
      </Text>

      <Image
        source={require('../assets/images/onboarding.png')}
        style={styles.image}
        resizeMode="contain"
      />

      <Pressable
        style={styles.button}
        onPress={() => navigation.navigate('Login')}>
        <Text style={styles.buttonText}>Get Started</Text>
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 20,
    paddingTop: 50,
  },
  heading: {
    fontSize: 45,
    fontFamily: 'Poppins-Regular',
    fontWeight: '600',
    color: '#000',
    marginBottom: 8,
    textAlign: 'center',
  },
  subheading: {
    fontSize: 45,
    fontFamily: 'Poppins-Regular',
    fontWeight: '600',
    color: '#01456A',
    textAlign: 'center',
  },
  bold: {
    fontWeight: '600',
  },
  description: {
    fontSize: 16,
    fontFamily: 'Poppins-Regular',
    color: '#000000',
    lineHeight: 24,
    textAlign: 'center',
    marginVertical: 20,
  },
  image: {
    width: 300,
    height: 390,
    marginVertical: 10,
  },
  button: {
    backgroundColor: '#022c43',
    paddingVertical: 12,
    width: '70%',
    marginTop: -10,
    paddingHorizontal: 10,
    borderRadius: 25,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    textAlign: 'center',
    fontFamily: 'Poppins-Regular',
    fontWeight: '600',
  },
});

export default OnboardingScreen;
