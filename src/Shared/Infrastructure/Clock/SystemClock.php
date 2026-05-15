<?php

declare(strict_types=1);

namespace App\Shared\Infrastructure\Clock;

use App\Shared\Application\Port\Clock\Clock;
use Symfony\Component\Clock\ClockInterface;

final class SystemClock implements Clock
{
    public function __construct(
        private readonly ClockInterface $clock,
    ) {
    }

    public function now(): \DateTimeImmutable
    {
        return $this->clock->now();
    }
}
