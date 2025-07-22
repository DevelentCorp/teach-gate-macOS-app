import React from 'react';
import {View, Text, Button, Pressable, StyleSheet} from 'react-native';

type AccountScreenProps = {
  toggleSidebar: () => void;
};

const AccountScreen: React.FC<AccountScreenProps> = ({toggleSidebar}) => {
  return (
    <View style={styles.container}>
      <Pressable onPress={toggleSidebar} style={styles.menuButton}>
        <Text style={styles.menuText}>☰</Text>
      </Pressable>

      <View style={styles.infoSection}>
        <Text style={styles.label}>Username: johndoe</Text>
        <Text style={styles.label}>First Name: John</Text>
        <Text style={styles.label}>User ID: 123456</Text>
      </View>

      <View style={styles.signOutButton}>
        <Button title="Sign Out" onPress={() => {}} />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {flex: 1, padding: 20},
  menuButton: {
    position: 'absolute',
    top: 20,
    left: 20,
    backgroundColor: '#fff',
    padding: 8,
    borderRadius: 4,
    zIndex: 10,
    elevation: 2,
  },
  menuText: {
    fontSize: 22,
  },
  infoSection: {
    marginTop: 80,
  },
  label: {
    fontSize: 18,
    marginBottom: 10,
  },
  signOutButton: {
    position: 'absolute',
    bottom: 30,
    width: '100%',
  },
});

export default AccountScreen;
