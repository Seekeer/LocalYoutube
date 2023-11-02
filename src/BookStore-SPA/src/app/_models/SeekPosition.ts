import {
  Pipe,
  PipeTransform,
} from '@angular/core';

export class SeekPosition {
    originalPosition: number;
    newPosition: number;
}

export class SeekPositionCollection { 
    public seekPositions: SeekPosition[] = [];
    public TryAddPosition(originalPosition: number, newPosition: number){

        if(newPosition==originalPosition)
            return; 

        if(this.seekPositions.length > 0){

            const lastPosition = this.seekPositions[this.seekPositions.length - 1];
            if(lastPosition.originalPosition == originalPosition)
            {
                lastPosition.newPosition = newPosition;
                return;
            }
        }

        if(this.seekPositions.find(x => x.newPosition == newPosition && x.originalPosition==originalPosition))
            return; 

       let seekPosition = new SeekPosition();
       seekPosition.originalPosition = originalPosition;
       seekPosition.newPosition = newPosition;
       this.seekPositions.push(seekPosition);
    }
}

@Pipe({
    name: 'durationDisplay'
})
export class DurationDisplayPipe implements PipeTransform {
    transform(duration:number): string {
        const oneDay = 24 * 3600 * 1000;
        const localOffset = new Date().getTimezoneOffset() * 60 * 1000;
        let date = new Date(duration*1000 + localOffset + oneDay) ;
        console.log(date);
        let dateStr = date.toLocaleTimeString();

        if(dateStr.startsWith('00:'))
            dateStr = dateStr.substring(3);

        return dateStr;
    }    
}