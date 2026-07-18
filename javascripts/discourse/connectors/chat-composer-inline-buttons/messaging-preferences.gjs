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

function sameUserId(first, second) {
  return (
    first !== null &&
    first !== undefined &&
    String(first) === String(second)
  );
}

export default class MessagingPreferencesChatConnector extends Component {
  @service currentUser;
  @service messagingPreferencesGate;
  @service siteSettings;

  get channel() {
    return this.args.channel || this.args.outletArgs?.channel;
  }

  get targetUsername() {
    const channel = this.channel;

    if (
      !this.currentUser ||
      !channel?.isDirectMessageChannel ||
      channel.chatable?.group === true ||
      !settingEnabled(this.siteSettings?.messaging_preferences_enabled)
    ) {
      return null;
    }

    // Discourse omits the current member from serialized direct-message users
    // when another participant exists. A one-to-one DM therefore contains one
    // target user here; a self-DM contains only the current user.
    const targets = (channel.chatable?.users || []).filter(
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
