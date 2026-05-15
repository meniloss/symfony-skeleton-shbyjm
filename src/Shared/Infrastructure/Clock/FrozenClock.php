<?php

declare(strict_types=1);

namespace App\Shared\Infrastructure\Clock;

use App\Shared\Application\Port\Clock\Clock;

final class FrozenClock implements Clock
{
    public function __construct(
        private \DateTimeImmutable $now,
    ) {
    }

    public function now(): \DateTimeImmutable
    {
        return $this->now;
    }

    public function advance(\DateInterval $interval): void
    {
        $this->now = $this->now->add($interval);
    }
}
