import React from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TextInputProps,
  StyleProp,
  ViewStyle,
} from 'react-native';

interface CustomTextInputProps extends TextInputProps {
  label?: string;
}

const CustomTextInput = ({label, ...props}: CustomTextInputProps) => {
  return (
    <View style={styles.container}>
      {label && <Text style={styles.label}>{label}</Text>}
      <TextInput
        {...props}
        placeholder={props.placeholder || 'Enter text'}
        style={[styles.input, props.style]}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  label: {
    marginBottom: 4,
    fontSize: 14,
    marginLeft: 80,
    fontFamily: 'Poppins-Regular',
    textAlign: 'left',
    alignContent: 'flex-start',
    color: '#333',
    fontWeight: '300',
  },
  input: {
    borderWidth: 1,
    borderColor: '#E7E2DA',
    marginBottom: 12,
    padding: 10,
    width: '70%',
    color: '#000',
    borderRadius: 10,
    textAlign: 'left',
    marginLeft: 80,
    backgroundColor: '#FFFFFF',
  },
  container: {
    width: '100%',
    marginBottom: 16,
  },
});

export default CustomTextInput;
