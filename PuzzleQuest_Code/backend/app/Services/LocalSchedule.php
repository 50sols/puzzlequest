<?php
namespace App\Services;
use Carbon\CarbonImmutable;
final class LocalSchedule {
    /** Ambiguous fall-back time: first UTC occurrence. Gap: first valid local minute after the requested wall time. */
    public static function utc(string $wall,string $zone): CarbonImmutable {
        if(!in_array($zone,\DateTimeZone::listIdentifiers(),true))throw new \InvalidArgumentException('IANA timezone required');
        $tz=new \DateTimeZone($zone);$naive=\DateTimeImmutable::createFromFormat('!Y-m-d H:i',$wall,new \DateTimeZone('UTC'));if(!$naive||$naive->format('Y-m-d H:i')!==$wall)throw new \InvalidArgumentException('Local time must use YYYY-MM-DD HH:MM');
        $offsets=array_unique(array_column($tz->getTransitions($naive->getTimestamp()-172800,$naive->getTimestamp()+172800),'offset'));
        for($minute=0;$minute<=1440;$minute++){$local=$naive->modify('+'.$minute.' minutes');$matches=[];foreach($offsets as$offset){$candidate=CarbonImmutable::createFromTimestampUTC($local->getTimestamp()-$offset);if($candidate->setTimezone($zone)->format('Y-m-d H:i')===$local->format('Y-m-d H:i'))$matches[]=$candidate;}if($matches){usort($matches,fn($a,$b)=>$a->getTimestamp()<=>$b->getTimestamp());return $matches[0];}}
        throw new \InvalidArgumentException('Unresolvable local wall time');
    }
}
