<?php

declare(strict_types=1);

namespace App\Shared\Infrastructure\Messenger;

use Symfony\Component\EventDispatcher\EventDispatcherInterface;
use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\Middleware\MiddlewareInterface;
use Symfony\Component\Messenger\Middleware\StackInterface;
use Symfony\Component\Messenger\Stamp\HandledStamp;

/**
 * Dispatches domain events collected by aggregate roots after the Doctrine
 * transaction has been committed.
 *
 * Convention: handlers return a tuple [mixed $result, object[] $events].
 * This middleware reads the HandledStamp, extracts the events from the tuple,
 * and dispatches each one via the Symfony EventDispatcher.
 *
 * Must be registered AFTER doctrine_transaction in the command.bus middleware
 * chain so that events are dispatched only once the transaction succeeds.
 */
final class DispatchDomainEventsAfterCommitMiddleware implements MiddlewareInterface
{
    public function __construct(
        private readonly EventDispatcherInterface $eventDispatcher,
    ) {
    }

    public function handle(Envelope $envelope, StackInterface $stack): Envelope
    {
        $envelope = $stack->next()->handle($envelope, $stack);

        $stamp = $envelope->last(HandledStamp::class);

        if ($stamp === null) {
            return $envelope;
        }

        $result = $stamp->getResult();

        if (!\is_array($result) || \count($result) !== 2) {
            return $envelope;
        }

        [, $events] = $result;

        if (!\is_array($events)) {
            return $envelope;
        }

        foreach ($events as $event) {
            if (\is_object($event)) {
                $this->eventDispatcher->dispatch($event);
            }
        }

        return $envelope;
    }
}
