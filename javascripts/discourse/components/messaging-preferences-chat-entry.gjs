import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
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

function existingBannerHost(channelElement) {
  return Array.from(channelElement?.children || []).find((element) =>
    element.classList?.contains("messaging-preferences-chat-banner-host")
  );
}

export default class MessagingPreferencesChatEntry extends Component {
  @service currentUser;
  @service messagingPreferencesGate;
  @service siteSettings;

  @tracked portalElement;

  markerElement = null;

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

    // In a normal one-to-one direct chat Discourse usually omits the current
    // user from this list. The explicit filter also supports versions where
    // both participants are serialized.
    const targets = Array.from(channel.chatable?.users || []).filter(
      (user) => user?.username && !sameUserId(user.id, this.currentUser.id)
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

  initializeGate() {
    if (this.targetUsername) {
      // Block sending while the current server-side preference version is
      // being checked or still requires acknowledgement.
      this.messagingPreferencesGate.setChatBlocked(this.channel, true);
    } else {
      this.messagingPreferencesGate.clearChat(this.channel);
    }
  }

  attachBannerHost() {
    const channelElement = this.markerElement?.closest(".chat-channel");

    if (!channelElement) {
      this.portalElement = null;
      return;
    }

    let host = existingBannerHost(channelElement);

    if (!host) {
      host = document.createElement("div");
      host.className = "messaging-preferences-chat-banner-host";
      channelElement.prepend(host);
    }

    host.dataset.chatChannelId = String(this.channel?.id || "");
    this.portalElement = host;
  }

  @action
  setup(element) {
    this.markerElement = element;
    this.initializeGate();
    this.attachBannerHost();
  }

  @action
  targetChanged() {
    this.initializeGate();
    this.attachBannerHost();
  }

  @action
  cleanup() {
    this.messagingPreferencesGate.clearChat(this.channel);
    this.markerElement = null;
  }

  <template>
    <span
      class="messaging-preferences-chat-slot"
      data-messaging-preferences-chat-target={{this.targetUsername}}
      {{didInsert this.setup}}
      {{didUpdate this.targetChanged this.targetUsername this.channel}}
      {{willDestroy this.cleanup}}
    >
      {{#if this.targetUsername}}
        <DConditionalInElement @element={{this.portalElement}}>
          <MessagingPreferencesCard
            @username={{this.targetUsername}}
            @mode="chat"
            @onRequirementChange={{this.requirementChanged}}
          />
        </DConditionalInElement>
      {{/if}}
    </span>
  </template>
}
