import React, { useState } from 'react';
import { AiResponse } from '../types';
import { SparklesIcon } from './icons';

interface AiAssistantProps {
  onQuery: (query: string) => void;
  aiResponse: AiResponse | null;
  isLoading: boolean;
}

const AiAssistant: React.FC<AiAssistantProps> = ({ onQuery, aiResponse, isLoading }) => {
  const [query, setQuery] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (query.trim()) {
      onQuery(query.trim());
      setQuery('');
    }
  };

  const QuickReplyButton: React.FC<{ text: string }> = ({ text }) => (
    <button
      onClick={() => onQuery(text)}
      className="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm rounded-full hover:bg-gray-200 transition-colors"
    >
      {text}
    </button>
  );

  return (
    <div className="flex flex-col gap-4">
      <div>
        <form onSubmit={handleSubmit} className="flex gap-2">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Ask about dog-friendly spots..."
            className="flex-grow px-4 py-2 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-500"
            disabled={isLoading}
          />
          <button
            type="submit"
            className="px-4 py-2 bg-indigo-600 text-white font-semibold rounded-full hover:bg-indigo-700 disabled:bg-indigo-300 transition-colors"
            disabled={isLoading || !query.trim()}
          >
            Ask
          </button>
        </form>
      </div>

      {isLoading && (
        <div className="flex items-center justify-center p-8 gap-2 text-gray-600">
          <SparklesIcon className="w-6 h-6 animate-pulse text-indigo-500" />
          <span>Thinking...</span>
        </div>
      )}

      {aiResponse && (
        <div className="space-y-4">
          <div className="p-4 bg-gray-50 rounded-lg">
            <p className="text-gray-800 whitespace-pre-wrap">{aiResponse.text}</p>
          </div>
          {aiResponse.sources && aiResponse.sources.length > 0 && (
            <div>
              <h4 className="text-sm font-semibold text-gray-600 mb-2">Sources:</h4>
              <ul className="space-y-1 text-sm list-disc list-inside">
                {aiResponse.sources.map((source, index) => (
                  <li key={index}>
                    <a
                      href={source.maps.uri}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-indigo-600 hover:underline"
                    >
                      {source.maps.title || 'View on Map'}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
      
      {!isLoading && !aiResponse && (
        <div className="text-center p-4 text-gray-500">
            <p>I can help you find parks, cafes, and events for you and your dog!</p>
        </div>
      )}

      {!isLoading && (
        <div className="flex flex-wrap gap-2 justify-center">
            <QuickReplyButton text="Find cafes with patios" />
            <QuickReplyButton text="Any dog parks with water?" />
            <QuickReplyButton text="What's happening this weekend?" />
        </div>
      )}
    </div>
  );
};

export default AiAssistant;
