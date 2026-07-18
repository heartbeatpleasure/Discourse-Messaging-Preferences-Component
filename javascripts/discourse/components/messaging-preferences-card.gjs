import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { not } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

function themeI18n(key, options) {
  return i18n(themePrefix(key), options);
}

function normalizeUsername(username) {
  return String(username || "")
    .trim()
    .replace(/^@/, "");
}

function responseStatus(error) {
  return error?.jqXHR?.status || error?.status;
}

async function fetchPreferences(username) {
  const normalizedUsername = normalizeUsername(username);

  const response = await ajax(
    getURL(
      `/messaging-preferences/v1/users/${encodeURIComponent(normalizedUsername)}`
    ),
    { cache: false }
  );

  return response?.messaging_preferences || null;
}

export default class MessagingPreferencesCard extends Component {
  @tracked preferences;
  @tracked expanded = false;
  @tracked acknowledgementInProgress = false;
  @tracked errorMessage;
  @tracked activeUsername = null;

  requestSequence = 0;

  get mode() {
    return this.args.mode === "chat" ? "chat" : "message";
  }

  get shouldRender() {
    return this.preferences?.has_preferences === true;
  }

  get acknowledgementRequired() {
    return this.preferences?.acknowledgement_required === true;
  }

  get worksWell() {
    return this.preferences?.works_well || "";
  }

  get pleaseAvoid() {
    return this.preferences?.please_avoid || "";
  }

  get hostClass() {
    return `messaging-preferences-card-host messaging-preferences-card-host--${this.mode}`;
  }

  get title() {
    return themeI18n("messaging_preferences.display.title", {
      username: this.activeUsername,
    });
  }

  get description() {
    return themeI18n("messaging_preferences.display.description", {
      username: this.activeUsername,
    });
  }

  get compactLabel() {
    return themeI18n("messaging_preferences.display.compact_label", {
      username: this.activeUsername,
    });
  }

  get worksWellLabel() {
    return themeI18n("messaging_preferences.display.works_well");
  }

  get pleaseAvoidLabel() {
    return themeI18n("messaging_preferences.display.please_avoid");
  }

  get gotItLabel() {
    return themeI18n("messaging_preferences.display.got_it");
  }

  get viewLabel() {
    return themeI18n("messaging_preferences.display.view");
  }

  get closeLabel() {
    return themeI18n("messaging_preferences.display.close");
  }

  get compactTitle() {
    return themeI18n("messaging_preferences.display.view_title", {
      username: this.activeUsername,
    });
  }

  @action
  setup() {
    this.load(this.args.username);
  }

  @action
  usernameChanged(_element, username) {
    this.load(username);
  }

  async load(username) {
    const normalizedUsername = normalizeUsername(username);
    const requestSequence = ++this.requestSequence;

    this.preferences = null;
    this.errorMessage = null;
    this.expanded = false;
    this.activeUsername = normalizedUsername || null;

    if (!normalizedUsername) {
      this.args.onRequirementChange?.(false);
      return;
    }

    // Prevent sending until the current server-side preference version has
    // been checked. Every composer/chat open performs a fresh request.
    this.args.onRequirementChange?.(true);

    try {
      const preferences = await fetchPreferences(normalizedUsername);

      if (requestSequence !== this.requestSequence) {
        return;
      }

      if (!preferences?.has_preferences) {
        this.args.onRequirementChange?.(false);
        return;
      }

      this.preferences = preferences;
      this.expanded = preferences.acknowledgement_required === true;
      this.args.onRequirementChange?.(
        preferences.acknowledgement_required === true
      );
    } catch (error) {
      if (requestSequence !== this.requestSequence) {
        return;
      }

      this.args.onRequirementChange?.(false);

      const status = responseStatus(error);
      if (status !== 403 && status !== 404) {
        this.errorMessage = themeI18n(
          "messaging_preferences.display.load_error"
        );
      }
    }
  }

  @action
  show() {
    this.expanded = true;
  }

  @action
  close() {
    if (!this.acknowledgementRequired) {
      this.expanded = false;
    }
  }

  @action
  async acknowledge() {
    if (
      this.acknowledgementInProgress ||
      !this.activeUsername ||
      !this.preferences?.preferences_digest
    ) {
      return;
    }

    this.acknowledgementInProgress = true;
    this.errorMessage = null;

    try {
      const response = await ajax(
        getURL(
          `/messaging-preferences/v1/users/${encodeURIComponent(
            this.activeUsername
          )}/acknowledge`
        ),
        {
          type: "POST",
          data: {
            preferences_digest: this.preferences.preferences_digest,
          },
        }
      );

      const preferences = response?.messaging_preferences;
      if (!preferences) {
        throw new Error("Missing messaging preferences response");
      }

      this.preferences = preferences;
      this.expanded = false;
      this.args.onRequirementChange?.(false);
    } catch (error) {
      const status = responseStatus(error);

      if ([403, 404, 409, 422].includes(status)) {
        await this.load(this.activeUsername);
      } else {
        this.errorMessage = themeI18n(
          "messaging_preferences.display.acknowledge_error"
        );
      }
    } finally {
      this.acknowledgementInProgress = false;
    }
  }

  willDestroy() {
    if (super.willDestroy) {
      super.willDestroy(...arguments);
    }

    this.requestSequence += 1;
    this.args.onRequirementChange?.(false);
  }

  <template>
    <div
      class={{this.hostClass}}
      {{didInsert this.setup}}
      {{didUpdate this.usernameChanged @username}}
    >
      {{#if this.shouldRender}}
        {{#if this.expanded}}
          <DModal
            @title={{this.title}}
            @subtitle={{this.description}}
            @closeModal={{this.close}}
            @dismissable={{not this.acknowledgementRequired}}
            @submitOnEnter={{false}}
            @bodyClass="messaging-preferences-modal__body"
            class="messaging-preferences-modal"
          >
            <:body>
              <div class="messaging-preferences-modal__preferences">
                {{#if this.worksWell}}
                  <section class="messaging-preferences-modal__preference">
                    <h3 class="messaging-preferences-modal__label">
                      {{this.worksWellLabel}}
                    </h3>
                    <div class="messaging-preferences-modal__text">
                      {{this.worksWell}}
                    </div>
                  </section>
                {{/if}}

                {{#if this.pleaseAvoid}}
                  <section class="messaging-preferences-modal__preference">
                    <h3 class="messaging-preferences-modal__label">
                      {{this.pleaseAvoidLabel}}
                    </h3>
                    <div class="messaging-preferences-modal__text">
                      {{this.pleaseAvoid}}
                    </div>
                  </section>
                {{/if}}

                {{#if this.errorMessage}}
                  <div
                    class="messaging-preferences-modal__error"
                    role="alert"
                  >
                    {{this.errorMessage}}
                  </div>
                {{/if}}
              </div>
            </:body>

            <:footer>
              {{#if this.acknowledgementRequired}}
                <button
                  type="button"
                  class="btn btn-primary messaging-preferences-modal__acknowledge"
                  disabled={{this.acknowledgementInProgress}}
                  aria-busy={{this.acknowledgementInProgress}}
                  {{on "click" this.acknowledge}}
                >
                  {{this.gotItLabel}}
                </button>
              {{else}}
                <button
                  type="button"
                  class="btn btn-primary messaging-preferences-modal__done"
                  {{on "click" this.close}}
                >
                  {{this.closeLabel}}
                </button>
              {{/if}}
            </:footer>
          </DModal>
        {{else}}
          <button
            type="button"
            class="btn-flat messaging-preferences-card__compact"
            title={{this.compactTitle}}
            aria-label={{this.compactTitle}}
            aria-expanded="false"
            {{on "click" this.show}}
          >
            {{dIcon "circle-info"}}
            <span class="messaging-preferences-card__compact-label">
              {{this.compactLabel}}
            </span>
            <span class="messaging-preferences-card__compact-action">
              {{this.viewLabel}}
            </span>
          </button>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
