import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, set } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const WORKS_WELL_FIELD = "messaging_preferences_works_well";
const PLEASE_AVOID_FIELD = "messaging_preferences_please_avoid";
const MAX_LENGTH = 500;

function themeI18n(key, options) {
  return i18n(themePrefix(key), options);
}

export default class MessagingPreferencesConnector extends Component {
  @service siteSettings;

  @tracked worksWellValue = "";
  @tracked pleaseAvoidValue = "";
  @tracked isSaving = false;
  @tracked saved = false;
  @tracked loadFailed = false;
  @tracked saveFailed = false;
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

  get shouldRender() {
    return (
      this.siteSettings?.messaging_preferences_enabled !== false &&
      this.model &&
      this.model.can_edit !== false
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

  get saveLabel() {
    return themeI18n("messaging_preferences.settings.save");
  }

  get savingLabel() {
    return themeI18n("messaging_preferences.settings.saving");
  }

  get savedLabel() {
    return themeI18n("messaging_preferences.settings.saved");
  }

  get loadErrorLabel() {
    return themeI18n("messaging_preferences.settings.load_error");
  }

  get saveErrorLabel() {
    return themeI18n("messaging_preferences.settings.save_error");
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
        )
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
    this.saved = false;
    this.saveFailed = false;
    this.updateModelFields(this.worksWellValue, this.pleaseAvoidValue);
  }

  @action
  async savePreferences() {
    if (this.isSaving) {
      return;
    }

    this.isSaving = true;
    this.saved = false;
    this.saveFailed = false;

    try {
      const response = await ajax(getURL("/messaging-preferences/v1/me"), {
        type: "PUT",
        data: {
          works_well: this.worksWellValue,
          please_avoid: this.pleaseAvoidValue,
        },
      });

      this.applyServerPreferences(response?.messaging_preferences);
      this.hasLocalEdits = false;
      this.loadFailed = false;
      this.saved = true;
    } catch (error) {
      this.saveFailed = true;
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
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

        <div class="messaging-preferences-settings__actions">
          <button
            type="button"
            class="btn btn-primary messaging-preferences-settings__save"
            disabled={{this.isSaving}}
            aria-busy={{this.isSaving}}
            {{on "click" this.savePreferences}}
          >
            {{#if this.isSaving}}
              {{this.savingLabel}}
            {{else}}
              {{this.saveLabel}}
            {{/if}}
          </button>

          {{#if this.saved}}
            <span
              class="messaging-preferences-settings__saved"
              role="status"
            >
              {{this.savedLabel}}
            </span>
          {{/if}}
        </div>

        {{#if this.loadFailed}}
          <p class="messaging-preferences-settings__error" role="alert">
            {{this.loadErrorLabel}}
          </p>
        {{/if}}

        {{#if this.saveFailed}}
          <p class="messaging-preferences-settings__error" role="alert">
            {{this.saveErrorLabel}}
          </p>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
