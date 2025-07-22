import React from 'react';
import {View, Text, TouchableOpacity, StyleSheet} from 'react-native';

interface Props {
  onSelect: (screen: string) => void;
  selected: string;
}

const Sidebar: React.FC<Props> = ({onSelect, selected}) => {
  const items = ['Home', 'LiveTV', 'Account'];

  return (
    <View style={styles.sidebar}>
      {items.map(item => (
        <TouchableOpacity key={item} onPress={() => onSelect(item)}>
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
    width: 200,
    backgroundColor: '#f0f0f0',
    paddingTop: 50,
    paddingHorizontal: 10,
  },
  item: {fontSize: 18, marginVertical: 15, color: '#444'},
  active: {fontWeight: 'bold', color: '#000'},
});

export default Sidebar;
