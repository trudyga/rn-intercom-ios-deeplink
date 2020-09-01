import React from "react";
import { Text } from "react-native";

import { NativeModules } from "react-native";

const { DeepLink } = NativeModules;

const canHandleLinksSignal = async () => {
  await DeepLink.sendAppCanHandleLinksSignal();
};

const App = () => {
  useEffect(() => {
    /**
     * @summary You need to send a signal to the native part of application to unlock the `openUrl` thread
     */
    canHandleLinksSignal();

    /**
     * @summary At this moment you will be able to receive the deep linking events from intercom
     */
    Linking.addEventListener("url", (url) => console.log("url", url)); // Subscribe to listen deep links while applicaiton is launched
  }, []);

  useEffect(() => {
    /**
     * @summary `Linking.getInitialURL()` returns `undefined` by if application was opened by react-native-intercom push notification.
     * @note If you are to open an applicaiton by a url from a `Notes` application you will be able to acces initialUrl here.
     */
    Linking.getInitialURL().then((initialUrl) =>
      console.log("initialUrl", initialUrl)
    );
  }, []);

  return <Text>Fly to the moon</Text>;
};

export default App;
