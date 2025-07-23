import React, {useContext, useEffect} from 'react';
import {View, Text, TouchableOpacity, StyleSheet, Image} from 'react-native';
import {AuthContext} from '../context/AuthContext';
import axios from 'axios';

interface Props {
  onSelect: (screen: string) => void;
  selected: string;
  onClose?: () => void;
}

const Sidebar: React.FC<Props> = ({onSelect, selected, onClose}) => {
  const {token} = useContext(AuthContext);
  const [user, setUser] = React.useState<any>(null);

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
  const items = ['Home', 'LiveTV', 'Account'];

  const iconMap: {[key: string]: any} = {
    Home: require('../assets/images/house.png'),
    LiveTV: require('../assets/images/tv-minimal-play.png'),
    Account: require('../assets/images/user.png'),
  };
  return (
    <View style={styles.sidebar}>
      <TouchableOpacity style={styles.closeButton} onPress={onClose}>
        <Text style={styles.closeText}>×</Text>
      </TouchableOpacity>

      <View style={styles.avatarContainer}>
        <View style={styles.avatar}>
          <Image
            source={{
              uri: 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
            }}
            style={styles.avatar}
          />
        </View>
        <View>
          <Text style={styles.helloText}>Hello,</Text>
          <Text style={styles.usernameText}>{user?.username}</Text>
        </View>
      </View>

      {items.map(item => (
        <TouchableOpacity
          key={item}
          onPress={() => onSelect(item)}
          style={styles.itemContainer}>
          <Image source={iconMap[item]} style={styles.menuImage} />
          <Text style={[styles.item, selected === item && styles.active]}>
            {item}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  sidebar: {
    width: '100%',
    backgroundColor: 'white',
    paddingTop: 50,
    paddingHorizontal: 10,
    zIndex: 1000,
  },
  avatarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 30,
    marginLeft: 10,
    marginTop: 50,
  },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: 30,
    marginRight: 16,
    overflow: 'hidden',
  },
  avatarImage: {
    width: 60,
    height: 60,
    borderRadius: 30,
  },
  helloText: {
    fontSize: 16,
    fontWeight: '500',
    color: 'gray',
  },
  usernameText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#111',
  },
  closeButton: {
    position: 'absolute',
    top: 20,
    left: 10,
    backgroundColor: '#0B2838',
    borderRadius: 15,
    zIndex: 1,
    width: 50,
    height: 50,
    alignItems: 'center',
  },
  itemContainer: {
    paddingTop: 14,
    flexDirection: 'row',
  },
  menuImage: {
    width: 18,
    height: 18,
    marginVertical: 15,
    marginLeft: 30,
  },
  closeText: {
    fontSize: 40,
    color: 'white',
    textAlign: 'right',
  },
  item: {fontSize: 18, marginVertical: 15, color: '#444', marginLeft: 50},
  active: {fontWeight: 'bold', color: '#000'},
});

export default Sidebar;
