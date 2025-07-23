import {
  EventQueue,
  OutlineEvent,
} from '../../inspiration/client/src/www/model/events';

type Listener = (...args: any[]) => void;

class GenericEvent implements OutlineEvent {
  constructor(public args: any[]) {}
}

export class EventEmitter {
  private readonly eventQueue = new EventQueue();
  private readonly listeners: Map<string, Listener[]> = new Map();

  constructor() {
    this.eventQueue.subscribe(GenericEvent, (event: GenericEvent) => {
      const [eventName, ...args] = event.args;
      const listeners = this.listeners.get(eventName);
      if (listeners) {
        listeners.forEach(listener => listener(...args));
      }
    });
    this.eventQueue.startPublishing();
  }

  on(eventName: string, listener: Listener) {
    if (!this.listeners.has(eventName)) {
      this.listeners.set(eventName, []);
    }
    this.listeners.get(eventName)!.push(listener);
  }

  off(eventName: string, listenerToRemove: Listener) {
    const listeners = this.listeners.get(eventName);
    if (listeners) {
      this.listeners.set(
        eventName,
        listeners.filter(listener => listener !== listenerToRemove),
      );
    }
  }

  emit(eventName: string, ...args: any[]) {
    this.eventQueue.enqueue(new GenericEvent([eventName, ...args]));
  }
}
