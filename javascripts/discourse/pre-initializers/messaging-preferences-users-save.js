import { action, set } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";

const WORKS_WELL_FIELD = "messaging_preferences_works_well";
const PLEASE_AVOID_FIELD = "messaging_preferences_please_avoid";

function settingEnabled(value) {
  return value !== false && value !== "false" && value !== 0 && value !== "0";
}

function fieldValue(model, fieldName) {
  return model?.custom_fields?.[fieldName] || "";
}

function hasPreferenceFields(model) {
  const customFields = model?.custom_fields;

  return Boolean(
    customFields &&
      (Object.prototype.hasOwnProperty.call(customFields, WORKS_WELL_FIELD) ||
        Object.prototype.hasOwnProperty.call(customFields, PLEASE_AVOID_FIELD))
  );
}

function isCurrentUserModel(currentUser, model) {
  if (!currentUser || !model) {
    return false;
  }

  if (currentUser.id !== undefined && model.id !== undefined) {
    return String(currentUser.id) === String(model.id);
  }

  return (
    String(currentUser.username || "").toLowerCase() ===
    String(model.username || "").toLowerCase()
  );
}

function applyServerPreferences(model, preferences) {
  if (!model || !preferences) {
    return;
  }

  if (!model.custom_fields) {
    set(model, "custom_fields", {});
  }

  set(
    model.custom_fields,
    WORKS_WELL_FIELD,
    preferences.works_well || ""
  );
  set(
    model.custom_fields,
    PLEASE_AVOID_FIELD,
    preferences.please_avoid || ""
  );
}

export default {
  name: "messaging-preferences-users-save",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "controller:preferences/users",
        (Superclass) =>
          class extends Superclass {
            @service currentUser;
            @service siteSettings;

            @action
            async save() {
              this.set("saved", false);

              try {
                if (
                  settingEnabled(
                    this.siteSettings?.messaging_preferences_enabled
                  ) &&
                  isCurrentUserModel(this.currentUser, this.model) &&
                  hasPreferenceFields(this.model)
                ) {
                  this.model.set("isSaving", true);

                  const response = await ajax(
                    getURL("/messaging-preferences/v1/me"),
                    {
                      type: "PUT",
                      data: {
                        works_well: fieldValue(
                          this.model,
                          WORKS_WELL_FIELD
                        ),
                        please_avoid: fieldValue(
                          this.model,
                          PLEASE_AVOID_FIELD
                        ),
                      },
                    }
                  );

                  applyServerPreferences(
                    this.model,
                    response?.messaging_preferences
                  );
                }
              } catch (error) {
                popupAjaxError(error);
                return;
              } finally {
                this.model?.set("isSaving", false);
              }

              return super.save();
            }
          }
      );
    });
  },
};
