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

function normalizeRecipient(value) {
  if (typeof value === "string") {
    return value.trim().replace(/^@/, "");
  }

  return value?.username?.trim?.() || "";
}

function recipientsFrom(value) {
  if (Array.isArray(value)) {
    return value.map(normalizeRecipient).filter(Boolean);
  }

  return String(value || "")
    .split(",")
    .map(normalizeRecipient)
    .filter(Boolean);
}

export default class MessagingPreferencesComposerConnector extends Component {
  @service currentUser;
  @service messagingPreferencesGate;
  @service siteSettings;

  activeModel = null;

  get model() {
    return this.args.model || this.args.outletArgs?.model;
  }

  get targetUsername() {
    const model = this.model;

    if (
      !this.currentUser ||
      !model ||
      model.editingPost ||
      !model.privateMessage ||
      !settingEnabled(this.siteSettings?.messaging_preferences_enabled) ||
      !settingEnabled(
        this.siteSettings?.messaging_preferences_personal_messages_enabled
      )
    ) {
      return null;
    }

    if (model.creatingPrivateMessage) {
      if (model.hasTargetGroups === true) {
        return null;
      }

      const recipients = recipientsFrom(model.targetRecipients).filter(
        (username) =>
          username.toLowerCase() !== this.currentUser.username.toLowerCase()
      );

      return recipients.length === 1 ? recipients[0] : null;
    }

    const details = model.topic?.details;
    const allowedGroups = details?.allowed_groups || [];
    const allowedUsers = details?.allowed_users || [];

    if (allowedGroups.length > 0 || allowedUsers.length !== 2) {
      return null;
    }

    const currentUserIsParticipant = allowedUsers.some((user) =>
      sameUserId(user?.id, this.currentUser.id)
    );
    if (!currentUserIsParticipant) {
      return null;
    }

    const targets = allowedUsers.filter(
      (user) =>
        user?.username && !sameUserId(user.id, this.currentUser.id)
    );

    return targets.length === 1 ? targets[0].username : null;
  }

  @action
  requirementChanged(required) {
    this.messagingPreferencesGate.setComposerBlocked(
      this.activeModel || this.model,
      required === true
    );
  }

  @action
  initializeGate() {
    const acknowledgementEnabled = settingEnabled(
      this.siteSettings?.messaging_preferences_require_acknowledgement
    );

    this.messagingPreferencesGate.setComposerBlocked(
      this.activeModel || this.model,
      Boolean(this.targetUsername) && acknowledgementEnabled
    );
  }

  @action
  setupGate() {
    this.activeModel = this.model;
    this.initializeGate();
  }

  @action
  targetChanged() {
    if (this.activeModel && this.activeModel !== this.model) {
      this.messagingPreferencesGate.clearComposer(this.activeModel);
    }

    this.activeModel = this.model;
    this.initializeGate();
  }

  @action
  cleanup() {
    this.messagingPreferencesGate.clearComposer(this.activeModel || this.model);
    this.activeModel = null;
  }

  <template>
    <div
      class="messaging-preferences-composer-slot"
      {{didInsert this.setupGate}}
      {{didUpdate this.targetChanged this.targetUsername this.model}}
      {{willDestroy this.cleanup}}
    >
      {{#if this.targetUsername}}
        <MessagingPreferencesCard
          @username={{this.targetUsername}}
          @mode="message"
          @onRequirementChange={{this.requirementChanged}}
        />
      {{/if}}
    </div>
  </template>
}
