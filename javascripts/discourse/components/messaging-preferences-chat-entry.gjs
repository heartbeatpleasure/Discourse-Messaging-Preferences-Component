import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import MessagingPreferencesCard from "./messaging-preferences-card";

function settingEnabled(value) {
  return value !== false && value !== "false" && value !== 0 && value !== "0";
}

function sameUserId(first, second) {
  return (
    first !== null &&
    first !== undefined &&
    second !== null &&
    second !== undefined &&
    String(first) === String(second)
  );
}

export default class MessagingPreferencesChatEntry extends Component {
  @service currentUser;
  @service messagingPreferencesGate;
  @service siteSettings;

  get channel() {
    return this.args.outletArgs?.channel || this.args.channel;
  }

  get targetUsername() {
    const channel = this.channel;

    if (
      !this.currentUser ||
      !settingEnabled(this.siteSettings?.messaging_preferences_enabled) ||
      !channel?.isDirectMessageChannel ||
      channel.chatable?.group === true
    ) {
      return null;
    }

    // For normal direct chats Discourse omits the current user from the
    // serialized participants. The explicit filter also safely handles
    // versions where the current user is still included.
    const targets = Array.from(channel.chatable?.users || []).filter(
      (user) =>
        user?.username && !sameUserId(user.id, this.currentUser.id)
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
    if (this.targetUsername) {
      // Block the send action only while the current server-side preference
      // version is being checked or still needs acknowledgement.
      this.messagingPreferencesGate.setChatBlocked(this.channel, true);
    } else {
      this.messagingPreferencesGate.clearChat(this.channel);
    }
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
      data-messaging-preferences-chat-target={{this.targetUsername}}
      {{didInsert this.initializeGate}}
      {{didUpdate this.targetChanged this.targetUsername this.channel}}
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
