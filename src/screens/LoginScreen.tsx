import React, {useState, useContext} from 'react';
import {View, Button, StyleSheet, Text, Alert} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import {StackNavigationProp} from '@react-navigation/stack';
import axios from 'axios';
import Logo from '../components/Logo';
import CustomTextInput from '../components/TextInput';
import {AuthContext} from '../context/AuthContext';

type RootStackParamList = {
  Login: undefined;
  Main: undefined;
};

type LoginScreenNavigationProp = StackNavigationProp<
  RootStackParamList,
  'Login'
>;

const LoginScreen = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const navigation = useNavigation<LoginScreenNavigationProp>();
  const {login} = useContext(AuthContext);

  const handleLogin = async () => {
    if (!username || !password) {
      setError('Username and password are required.');
      return;
    }

    try {
      const response = await axios.post(
        'https://b-stg.cx-tg.develentcorp.com/api/auth/user/login',
        {
          username,
          password,
        },
      );

      if (response.data.token) {
        await login(response.data.token);
        navigation.navigate('Main');
      }
    } catch (err) {
      setError('Failed to login. Please check your credentials.');
      console.error('Login error:', err);
    }
  };

  return (
    <View style={styles.container}>
      <Logo />
      <CustomTextInput
        label="Username"
        placeholder="Username"
        onChangeText={setUsername}
        value={username}
        placeholderTextColor={'#A9A9A9'}
        keyboardType="default"
        autoCapitalize="none"
      />
      <CustomTextInput
        label="Password"
        placeholder="Password"
        secureTextEntry
        onChangeText={setPassword}
        value={password}
        placeholderTextColor={'#A9A9A9'}
      />
      {error ? <Text style={styles.errorText}>{error}</Text> : null}
      <View style={styles.buttonContainer}>
        <Button title="Sign In" onPress={handleLogin} color="#fff" />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    padding: 14,
    flex: 1,
    paddingTop: 100,
    backgroundColor: '#fff',
  },
  buttonContainer: {
    marginTop: 10,
    width: '70%',
    borderRadius: 30,
    backgroundColor: '#0B2838',
    elevation: 2,
  },
  errorText: {
    color: 'red',
    marginBottom: 10,
  },
});

export default LoginScreen;
