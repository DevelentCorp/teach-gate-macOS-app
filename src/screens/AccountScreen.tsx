import {useEffect, useState, useContext} from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import {AuthContext} from '../context/AuthContext';
import axios from 'axios';
type AccountScreenProps = {
  toggleSidebar: () => void;
};

const AccountScreen: React.FC<AccountScreenProps> = ({toggleSidebar}) => {
  const {token, logout} = useContext(AuthContext);
  const [user, setUser] = useState<any>(null);
  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get(
          'https://b-stg.cx-tg.develentcorp.com/api/user/profile',
          {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          },
        );
        setUser(response.data);
      } catch (err) {
        console.error(err);
      }
    };

    if (token) {
      fetchData();
    }
  }, [token]);
  return (
    <View style={styles.container}>
      <Pressable onPress={toggleSidebar} style={styles.menuButton}>
        <Text style={styles.menuText}>☰</Text>
      </Pressable>

      <Text style={styles.title}>My Account</Text>

      <View style={styles.card}>
        <Text style={styles.boldLabel}>
          Username <Text style={styles.normalLabel}>: {user?.username}</Text>
        </Text>
        <Text style={styles.boldLabel}>
          Name <Text style={styles.normalLabel}>: {user?.firstName}</Text>
        </Text>
        <Text style={styles.boldLabel}>
          User ID <Text style={styles.normalLabel}>: {user?.id}</Text>
        </Text>
      </View>

      {/* <View style={styles.infoRow}>
        <Text style={styles.infoText}>My ID : {user?.id}</Text>
        <Text style={styles.copyIcon}>{'\uD83D\uDCCB'}</Text>
      </View> */}

      <TouchableOpacity style={styles.signOutButton} onPress={logout}>
        <Text style={styles.signOutText}>Sign Out</Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#fff',
  },
  menuButton: {
    position: 'absolute',
    top: 20,
    left: 20,
    backgroundColor: 'white',
    borderRadius: 30,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
    padding: 10,
    color: '#2A66EA',
    zIndex: 1,
  },
  menuText: {
    fontSize: 22,
    color: '#2A66EA',
  },
  title: {
    fontSize: 26,
    fontWeight: 'bold',
    color: '#000',
    alignSelf: 'center',
    marginTop: 5,
  },
  card: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 10,
    marginTop: 60,
    gap: 10,
    elevation: 5,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 6,
    shadowOffset: {width: 0, height: 3},
  },
  boldLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 6,
  },
  normalLabel: {
    fontWeight: 'normal',
    color: '#333',
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
    padding: 16,
    marginLeft: 5,
  },
  infoText: {
    fontSize: 16,
    flex: 1,
    color: '#000',
    fontWeight: '500',
  },
  copyIcon: {
    fontSize: 18,
    marginLeft: 8,
  },
  signOutButton: {
    backgroundColor: '#002638',
    paddingVertical: 15,
    paddingHorizontal: 25,
    borderRadius: 30,
    position: 'absolute',
    bottom: 30,
    alignSelf: 'center',
    width: '90%',
    flexDirection: 'row',
    justifyContent: 'center',
  },
  signOutText: {
    color: '#fff',
    fontSize: 18,
  },
});

export default AccountScreen;
