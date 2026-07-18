import { apiInitializer } from "discourse/lib/api";
import MessagingPreferencesChatEntry from "../components/messaging-preferences-chat-entry";

// Register through Discourse's supported outlet API instead of relying on
// automatic connector discovery inside the separately bundled Chat plugin.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "chat-composer-inline-buttons",
    MessagingPreferencesChatEntry
  );
});
