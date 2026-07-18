import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const CACHE_TTL_MS = 10_000;
const preferenceCache = new Map();

function themeI18n(key, options) {
  return i18n(themePrefix(key), options);
}

function normalizeUsername(username) {
  return String(username || "")
    .trim()
    .replace(/^@/, "");
}

function cacheKeyFor(viewerUserId, username) {
  const normalizedUsername = normalizeUsername(username).toLowerCase();
  return `${viewerUserId || "anonymous"}:${normalizedUsername}`;
}

function responseStatus(error) {
  return error?.jqXHR?.status || error?.status;
}

async function fetchPreferences(username, viewerUserId, { force = false } = {}) {
  const normalizedUsername = normalizeUsername(username);
  const cacheKey = cacheKeyFor(viewerUserId, normalizedUsername);
  const cached = preferenceCache.get(cacheKey);

  if (!force && cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
    return cached.preferences;
  }

  const response = await ajax(
    getURL(
      `/messaging-preferences/v1/users/${encodeURIComponent(normalizedUsername)}`
    )
  );
  const preferences = response?.messaging_preferences || null;

  preferenceCache.set(cacheKey, {
    fetchedAt: Date.now(),
    preferences,
  });

  return preferences;
}

function cachePreferences(username, viewerUserId, preferences) {
  const normalizedUsername = normalizeUsername(username);
  if (!normalizedUsername) {
    return;
  }

  preferenceCache.set(cacheKeyFor(viewerUserId, normalizedUsername), {
    fetchedAt: Date.now(),
    preferences,
  });
}

export default class MessagingPreferencesCard extends Component {
  @service currentUser;

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

  get hideLabel() {
    return themeI18n("messaging_preferences.display.hide");
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

  async load(username, { force = false } = {}) {
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

    // Prevent a quick send while the current preference version is being checked.
    this.args.onRequirementChange?.(true);

    try {
      const preferences = await fetchPreferences(
        normalizedUsername,
        this.currentUser?.id,
        { force }
      );

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
  hide() {
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
      cachePreferences(
        this.activeUsername,
        this.currentUser?.id,
        preferences
      );
      this.expanded = false;
      this.args.onRequirementChange?.(false);
    } catch (error) {
      const status = responseStatus(error);

      if ([403, 404, 409, 422].includes(status)) {
        await this.load(this.activeUsername, { force: true });
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
          <section
            class="messaging-preferences-card"
            aria-label={{this.title}}
          >
            <div class="messaging-preferences-card__header">
              <div class="messaging-preferences-card__heading">
                {{dIcon "circle-info"}}
                <strong>{{this.title}}</strong>
              </div>

              {{#unless this.acknowledgementRequired}}
                <button
                  type="button"
                  class="btn-flat messaging-preferences-card__close"
                  title={{this.hideLabel}}
                  aria-label={{this.hideLabel}}
                  {{on "click" this.hide}}
                >
                  {{dIcon "xmark"}}
                </button>
              {{/unless}}
            </div>

            <div class="messaging-preferences-card__content">
              {{#if this.worksWell}}
                <div class="messaging-preferences-card__preference">
                  <div class="messaging-preferences-card__label">
                    {{this.worksWellLabel}}
                  </div>
                  <div class="messaging-preferences-card__text">
                    {{this.worksWell}}
                  </div>
                </div>
              {{/if}}

              {{#if this.pleaseAvoid}}
                <div class="messaging-preferences-card__preference">
                  <div class="messaging-preferences-card__label">
                    {{this.pleaseAvoidLabel}}
                  </div>
                  <div class="messaging-preferences-card__text">
                    {{this.pleaseAvoid}}
                  </div>
                </div>
              {{/if}}
            </div>

            {{#if this.errorMessage}}
              <div
                class="messaging-preferences-card__error"
                role="alert"
              >
                {{this.errorMessage}}
              </div>
            {{/if}}

            <div class="messaging-preferences-card__actions">
              {{#if this.acknowledgementRequired}}
                <button
                  type="button"
                  class="btn btn-primary messaging-preferences-card__acknowledge"
                  disabled={{this.acknowledgementInProgress}}
                  {{on "click" this.acknowledge}}
                >
                  {{this.gotItLabel}}
                </button>
              {{else}}
                <button
                  type="button"
                  class="btn-flat messaging-preferences-card__hide"
                  {{on "click" this.hide}}
                >
                  {{this.hideLabel}}
                </button>
              {{/if}}
            </div>
          </section>
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
