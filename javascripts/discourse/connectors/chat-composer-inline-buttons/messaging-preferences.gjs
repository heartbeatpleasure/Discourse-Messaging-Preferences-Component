import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import MessagingPreferencesCard from "../../components/messaging-preferences-card";

function settingEnabled(value) {
  return value !== false && value !== "false" && value !== 0 && value !== "0";
}
function sameUser(first, second) {
  if (!first || !second) {
    return false;
  }

  if (
    first.id !== null &&
    first.id !== undefined &&
    second.id !== null &&
    second.id !== undefined
  ) {
    return String(first.id) === String(second.id);
  }

  return (
    String(first.username || "").toLowerCase() ===
    String(second.username || "").toLowerCase()
  );
}

function isDirectMessageChannel(channel) {
  return (
    channel?.isDirectMessageChannel === true ||
    channel?.chatableType === "DirectMessage" ||
    channel?.chatable_type === "DirectMessage" ||
    channel?.chatable?.type === "DirectMessage"
  );
}

export default class MessagingPreferencesChatConnector extends Component {
  @service currentUser;
  @service messagingPreferencesGate;
  @service siteSettings;

  get composer() {
    return this.args.composer || this.args.outletArgs?.composer;
  }

  get channel() {
    return (
      this.args.channel ||
      this.args.outletArgs?.channel ||
      this.composer?.args?.channel ||
      null
    );
  }

  get targetUsername() {
    const channel = this.channel;

    if (
      !this.currentUser ||
      !isDirectMessageChannel(channel) ||
      Boolean(channel?.chatable?.group) ||
      !settingEnabled(this.siteSettings?.messaging_preferences_enabled)
    ) {
      return null;
    }

    const users = channel?.chatable?.users || channel?.users || [];
    const targets = users.filter(
      (user) => user?.username && !sameUser(user, this.currentUser)
    );

    return targets.length === 1 ? targets[0].username : null;
  }

  @action
  requirementChanged(required) {
    this.messagingPreferencesGate.setChatBlocked(
      this.channel,
      required === true
    );
  }

  @action
  initializeGate() {
    this.messagingPreferencesGate.setChatBlocked(
      this.channel,
      Boolean(this.targetUsername)
    );
  }

  @action
  targetChanged() {
    this.initializeGate();
  }

  @action
  cleanup() {
    this.messagingPreferencesGate.clearChat(this.channel);
  }

  <template>
    <div
      class="messaging-preferences-chat-slot"
      {{didInsert this.initializeGate}}
      {{didUpdate this.targetChanged this.targetUsername}}
      {{willDestroy this.cleanup}}
    >
      {{#if this.targetUsername}}
        <MessagingPreferencesCard
          @username={{this.targetUsername}}
          @mode="chat"
          @onRequirementChange={{this.requirementChanged}}
        />
      {{/if}}
    </div>
  </template>
}
