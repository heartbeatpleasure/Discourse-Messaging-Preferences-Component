import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "messaging-preferences-send-gate",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "service:composer",
        (Superclass) =>
          class extends Superclass {
            @service messagingPreferencesGate;

            get disableSubmit() {
              return (
                super.disableSubmit ||
                this.messagingPreferencesGate.isComposerBlocked(this.model)
              );
            }
          }
      );

      // The channel composer is the concrete component instantiated for
      // normal direct chats. Extending it directly makes the gate independent
      // of whether the abstract base chat-composer class was imported earlier.
      api.modifyClass(
        "component:chat/composer/channel",
        (Superclass) =>
          class extends Superclass {
            @service messagingPreferencesGate;

            get sendEnabled() {
              return (
                super.sendEnabled &&
                !this.messagingPreferencesGate.isChatBlocked(this.args.channel)
              );
            }
          },
        { ignoreMissing: true }
      );
    });
  },
};
