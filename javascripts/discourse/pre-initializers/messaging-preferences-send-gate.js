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

      api.modifyClass(
        "component:chat-composer",
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
