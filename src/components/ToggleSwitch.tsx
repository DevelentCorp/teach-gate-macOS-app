import React, {useState} from 'react';
import {View, Text, StyleSheet, TouchableOpacity} from 'react-native';

interface ToggleSwitchProps {
  isOn: boolean;
  onToggle: () => void;
}

const ToggleSwitch: React.FC<ToggleSwitchProps> = ({isOn, onToggle}) => {
  return (
    <TouchableOpacity onPress={onToggle}>
      <View style={[styles.container, isOn ? styles.on : styles.off]}>
        <View style={[styles.thumb, isOn ? styles.thumbOn : styles.thumbOff]} />
        {isOn && <Text style={styles.textOn}>ON</Text>}
        {!isOn && <Text style={styles.textOff}>OFF</Text>}
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    width: 200,
    height: 90,
    borderRadius: 50,
    justifyContent: 'center',
  },
  on: {
    backgroundColor: '#00456A',
  },
  off: {
    backgroundColor: '#D1D4DB',
  },
  thumb: {
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: 'white',
    position: 'absolute',
  },
  thumbOn: {
    right: 5,
  },
  thumbOff: {
    left: 5,
  },
  textOff: {
    color: '#A5A8AF',
    fontSize: 50,
    fontWeight: 600,
    position: 'absolute',
    right: 25,
  },
  textOn: {
    color: '#00517D',
    fontSize: 55,
    fontWeight: 'bold',
    position: 'absolute',
    left: 24,
  },
});

export default ToggleSwitch;
