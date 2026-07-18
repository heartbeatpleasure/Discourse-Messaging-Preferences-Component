import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class MessagingPreferencesGateService extends Service {
  @tracked revision = 0;

  composerBlocks = new WeakMap();
  chatBlocks = new WeakMap();

  setComposerBlocked(model, blocked) {
    this._set(this.composerBlocks, model, blocked);
  }

  clearComposer(model) {
    this._clear(this.composerBlocks, model);
  }

  isComposerBlocked(model) {
    return Boolean(
      this.revision >= 0 && model && this.composerBlocks.get(model)
    );
  }

  setChatBlocked(channel, blocked) {
    this._set(this.chatBlocks, channel, blocked);
  }

  clearChat(channel) {
    this._clear(this.chatBlocks, channel);
  }

  isChatBlocked(channel) {
    return Boolean(
      this.revision >= 0 && channel && this.chatBlocks.get(channel)
    );
  }

  _set(collection, object, blocked) {
    if (!object) {
      return;
    }

    const currentlyBlocked = collection.has(object);
    const shouldBlock = blocked === true;

    if (currentlyBlocked === shouldBlock) {
      return;
    }

    if (shouldBlock) {
      collection.set(object, true);
    } else {
      collection.delete(object);
    }

    this.revision += 1;
  }

  _clear(collection, object) {
    if (!object || !collection.has(object)) {
      return;
    }

    collection.delete(object);
    this.revision += 1;
  }
}
