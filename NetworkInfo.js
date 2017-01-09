'use strict';

var RNNetworkInfo = require('react-native').NativeModules.RNNetworkInfo;

var NetworkInfo = {
  getSSID(ssid) {
    RNNetworkInfo.getSSID(ssid);
  },

  getIPAddress(ip) {
    RNNetworkInfo.getIPAddress(ip);
  },

  getRouterIPAddress(ip) {
    RNNetworkInfo.getRouterIPAddress(ip);
  }
};

module.exports = NetworkInfo;
