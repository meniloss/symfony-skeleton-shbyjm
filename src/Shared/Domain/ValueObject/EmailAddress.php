<?php

declare(strict_types=1);

namespace App\Shared\Domain\ValueObject;

use InvalidArgumentException;

final class EmailAddress
{
    private readonly string $value;

    public function __construct(string $value)
    {
        $value = trim(mb_strtolower($value));

        if ($value === '') {
            throw new InvalidArgumentException('Email address cannot be empty.');
        }

        if (filter_var($value, FILTER_VALIDATE_EMAIL) === false) {
            throw new InvalidArgumentException('Invalid email address.');
        }

        if (mb_strlen($value) > 180) {
            throw new InvalidArgumentException('Email address is too long.');
        }

        $this->value = $value;
    }

    public function value(): string
    {
        return $this->value;
    }

    public function equals(self $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
