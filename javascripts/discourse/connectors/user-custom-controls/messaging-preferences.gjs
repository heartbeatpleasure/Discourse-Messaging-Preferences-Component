import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const WORKS_WELL_FIELD = "messaging_preferences_works_well";
const PLEASE_AVOID_FIELD = "messaging_preferences_please_avoid";
const MAX_LENGTH = 500;

function themeI18n(key, options) {
  return i18n(themePrefix(key), options);
}

function settingEnabled(value) {
  return value !== false && value !== "false" && value !== 0 && value !== "0";
}

export default class MessagingPreferencesConnector extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked worksWellValue = "";
  @tracked pleaseAvoidValue = "";
  @tracked loadFailed = false;
  @tracked hasLoadedFromServer = false;
  @tracked hasLocalEdits = false;

  maxLength = MAX_LENGTH;

  constructor(owner, args) {
    super(owner, args);

    const model = args.model || args.outletArgs?.model;
    const customFields = model?.custom_fields || {};

    this.worksWellValue = customFields[WORKS_WELL_FIELD] || "";
    this.pleaseAvoidValue = customFields[PLEASE_AVOID_FIELD] || "";
  }

  get model() {
    return this.args.model || this.args.outletArgs?.model;
  }

  get isCurrentUser() {
    if (!this.currentUser || !this.model) {
      return false;
    }

    if (this.currentUser.id !== undefined && this.model.id !== undefined) {
      return String(this.currentUser.id) === String(this.model.id);
    }

    return (
      String(this.currentUser.username || "").toLowerCase() ===
      String(this.model.username || "").toLowerCase()
    );
  }

  get shouldRender() {
    const featureEnabled = settingEnabled(
      this.siteSettings?.messaging_preferences_enabled
    );
    const hasEnabledContext =
      settingEnabled(
        this.siteSettings?.messaging_preferences_personal_messages_enabled
      ) ||
      settingEnabled(
        this.siteSettings?.messaging_preferences_direct_chat_enabled
      );

    return (
      featureEnabled &&
      hasEnabledContext &&
      this.model?.can_edit !== false &&
      this.isCurrentUser
    );
  }

  get title() {
    return themeI18n("messaging_preferences.settings.title");
  }

  get description() {
    return themeI18n("messaging_preferences.settings.description");
  }

  get worksWellLabel() {
    return themeI18n("messaging_preferences.settings.works_well.label");
  }

  get worksWellDescription() {
    return themeI18n("messaging_preferences.settings.works_well.description");
  }

  get worksWellPlaceholder() {
    return themeI18n("messaging_preferences.settings.works_well.placeholder");
  }

  get pleaseAvoidLabel() {
    return themeI18n("messaging_preferences.settings.please_avoid.label");
  }

  get pleaseAvoidDescription() {
    return themeI18n("messaging_preferences.settings.please_avoid.description");
  }

  get pleaseAvoidPlaceholder() {
    return themeI18n("messaging_preferences.settings.please_avoid.placeholder");
  }

  get saveHint() {
    return themeI18n("messaging_preferences.settings.save_hint", {
      username: this.currentUser?.username || this.model?.username,
    });
  }

  get worksWell() {
    return this.worksWellValue;
  }

  get pleaseAvoid() {
    return this.pleaseAvoidValue;
  }

  get worksWellCount() {
    return this.worksWell.length;
  }

  get worksWellCountLabel() {
    return themeI18n("messaging_preferences.settings.character_count", {
      used: this.worksWellCount,
      maximum: this.maxLength,
    });
  }

  get pleaseAvoidCount() {
    return this.pleaseAvoid.length;
  }

  get pleaseAvoidCountLabel() {
    return themeI18n("messaging_preferences.settings.character_count", {
      used: this.pleaseAvoidCount,
      maximum: this.maxLength,
    });
  }

  get loadErrorLabel() {
    return themeI18n("messaging_preferences.settings.load_error");
  }

  updateModelFields(worksWell, pleaseAvoid) {
    if (!this.model) {
      return;
    }

    if (!this.model.custom_fields) {
      set(this.model, "custom_fields", {});
    }

    set(this.model.custom_fields, WORKS_WELL_FIELD, worksWell);
    set(this.model.custom_fields, PLEASE_AVOID_FIELD, pleaseAvoid);
  }

  applyServerPreferences(preferences) {
    const worksWell = preferences?.works_well || "";
    const pleaseAvoid = preferences?.please_avoid || "";

    this.worksWellValue = worksWell;
    this.pleaseAvoidValue = pleaseAvoid;
    this.updateModelFields(worksWell, pleaseAvoid);
  }

  @action
  async loadPreferences() {
    if (this.hasLoadedFromServer || !this.model?.username) {
      return;
    }

    this.hasLoadedFromServer = true;
    this.loadFailed = false;

    try {
      const response = await ajax(
        getURL(
          `/messaging-preferences/v1/users/${encodeURIComponent(this.model.username)}`
        ),
        { cache: false }
      );

      if (!this.hasLocalEdits) {
        this.applyServerPreferences(response?.messaging_preferences);
      }
    } catch {
      this.loadFailed = true;
    }
  }

  @action
  updateField(fieldName, event) {
    const value = event.target.value.slice(0, MAX_LENGTH);

    if (fieldName === WORKS_WELL_FIELD) {
      this.worksWellValue = value;
    } else if (fieldName === PLEASE_AVOID_FIELD) {
      this.pleaseAvoidValue = value;
    }

    this.hasLocalEdits = true;
    this.updateModelFields(this.worksWellValue, this.pleaseAvoidValue);
  }

  <template>
    {{#if this.shouldRender}}
      <section
        class="messaging-preferences-settings"
        data-setting-name="user-messaging-preferences"
        {{didInsert this.loadPreferences}}
        ...attributes
      >
        <h2 class="messaging-preferences-settings__title">
          {{this.title}}
        </h2>

        <p class="messaging-preferences-settings__description">
          {{this.description}}
        </p>

        <div class="messaging-preferences-settings__field control-group">
          <label for="messaging-preferences-works-well" class="control-label">
            {{this.worksWellLabel}}
          </label>
          <p
            id="messaging-preferences-works-well-help"
            class="instructions"
          >
            {{this.worksWellDescription}}
          </p>
          <textarea
            id="messaging-preferences-works-well"
            class="input-xxlarge messaging-preferences-settings__textarea"
            rows="4"
            maxlength={{this.maxLength}}
            value={{this.worksWell}}
            placeholder={{this.worksWellPlaceholder}}
            aria-describedby="messaging-preferences-works-well-help messaging-preferences-works-well-count"
            {{on "input" (fn this.updateField WORKS_WELL_FIELD)}}
          ></textarea>
          <div
            id="messaging-preferences-works-well-count"
            class="messaging-preferences-settings__count"
            aria-live="polite"
          >
            {{this.worksWellCountLabel}}
          </div>
        </div>

        <div class="messaging-preferences-settings__field control-group">
          <label for="messaging-preferences-please-avoid" class="control-label">
            {{this.pleaseAvoidLabel}}
          </label>
          <p
            id="messaging-preferences-please-avoid-help"
            class="instructions"
          >
            {{this.pleaseAvoidDescription}}
          </p>
          <textarea
            id="messaging-preferences-please-avoid"
            class="input-xxlarge messaging-preferences-settings__textarea"
            rows="4"
            maxlength={{this.maxLength}}
            value={{this.pleaseAvoid}}
            placeholder={{this.pleaseAvoidPlaceholder}}
            aria-describedby="messaging-preferences-please-avoid-help messaging-preferences-please-avoid-count"
            {{on "input" (fn this.updateField PLEASE_AVOID_FIELD)}}
          ></textarea>
          <div
            id="messaging-preferences-please-avoid-count"
            class="messaging-preferences-settings__count"
            aria-live="polite"
          >
            {{this.pleaseAvoidCountLabel}}
          </div>
        </div>

        <p class="messaging-preferences-settings__save-hint">
          {{this.saveHint}}
        </p>

        {{#if this.loadFailed}}
          <p class="messaging-preferences-settings__error" role="alert">
            {{this.loadErrorLabel}}
          </p>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
